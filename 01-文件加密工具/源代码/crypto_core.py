"""加密核心逻辑（不含任何界面代码）。

设计要点（对应 REQUIREMENTS.md）：
- 使用成熟库 cryptography：AES-256-GCM 认证加密 + scrypt 密钥派生，不自研算法。
- 随机生成内容密钥 CEK 加密实际数据；CEK 再分别由“文件密码”和可选的“恢复密码”
  独立封装成两条解锁路径。未启用恢复时，包内不存在恢复数据，因此没有通用密码/后门。
- 所有密码只用于派生密钥，不做明文存储；提示（hint）为明文字段，不得包含密码。
- 认证全部通过之前不创建、不写入任何输出文件（失败不落盘）。
- 原件只读、不删除不修改；输出冲突一律拒绝，不覆盖。
"""

from __future__ import annotations

import base64
import io
import json
import os
import struct
import zipfile

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt

# 容器格式常量
MAGIC = b"PYENC"
FORMAT_VERSION = 1
KEY_LEN = 32          # AES-256
NONCE_LEN = 12        # GCM 推荐 nonce 长度
SALT_LEN = 16
# scrypt 参数（教学原型，约 16MB 内存开销）
KDF_PARAMS = {"n": 2 ** 14, "r": 8, "p": 1, "dklen": KEY_LEN}


# --------------------------------------------------------------------------- #
# 异常类型：界面层据此显示友好、清晰的提示
# --------------------------------------------------------------------------- #
class CryptoToolError(Exception):
    """所有本工具异常的基类。"""


class ValidationError(CryptoToolError):
    """输入校验未通过（空密码、密码相同、提示含密码等）。"""


class InvalidPackageError(CryptoToolError):
    """加密包无法识别、已损坏或被篡改。"""


class WrongPasswordError(CryptoToolError):
    """密码认证失败；不会产生任何解密结果。"""


class RecoveryNotEnabledError(CryptoToolError):
    """该加密包在加密时未启用恢复。"""


class OutputExistsError(CryptoToolError):
    """目标输出已存在，拒绝覆盖。"""


class NonEmptyDirectoryError(CryptoToolError):
    """解密输出目录非空，拒绝直接写入。"""


# --------------------------------------------------------------------------- #
# 小工具
# --------------------------------------------------------------------------- #
def _b64e(data: bytes) -> str:
    return base64.b64encode(data).decode("ascii")


def _b64d(text: str) -> bytes:
    return base64.b64decode(text.encode("ascii"), validate=True)


def _derive_key(password: str, salt: bytes, params: dict) -> bytes:
    kdf = Scrypt(
        salt=salt,
        length=params["dklen"],
        n=params["n"],
        r=params["r"],
        p=params["p"],
    )
    return kdf.derive(password.encode("utf-8"))


def _aad_from_header(header: dict) -> bytes:
    """根据公开（非密文）字段构造关联数据 AAD。

    加密与解密都调用本函数，保证 AAD 字节一致；任何对 salt/nonce/参数/提示的
    篡改都会让 GCM 认证失败。
    """
    aad_subset = {
        "format": header["format"],
        "kdf": header["kdf"],
        "kdf_params": header["kdf_params"],
        "root_type": header["root_type"],
        "root_name": header["root_name"],
        "hint": header["hint"],
        "file": {"salt": header["file"]["salt"], "nonce": header["file"]["nonce"]},
        "recovery": (
            None
            if header["recovery"] is None
            else {
                "salt": header["recovery"]["salt"],
                "nonce": header["recovery"]["nonce"],
            }
        ),
        "payload": {"nonce": header["payload"]["nonce"]},
    }
    return json.dumps(aad_subset, sort_keys=True, separators=(",", ":")).encode("utf-8")


# --------------------------------------------------------------------------- #
# 归档：把文件/文件夹打包成 ZIP 字节（保留子目录），以及还原
# --------------------------------------------------------------------------- #
def _build_archive(source_path: str) -> tuple[str, str, bytes]:
    source = os.path.abspath(source_path)
    if not os.path.exists(source):
        raise ValidationError(f"选择的对象不存在：{source}")

    root_name = os.path.basename(source.rstrip(os.sep))
    if not root_name:
        raise ValidationError("无法取得所选对象的名称。")

    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
        if os.path.isfile(source):
            zf.write(source, arcname=root_name)
            root_type = "file"
        else:
            root_type = "dir"
            for dirpath, dirnames, filenames in os.walk(source):
                for name in filenames:
                    full = os.path.join(dirpath, name)
                    rel = os.path.relpath(full, source)
                    arc = os.path.join(root_name, rel).replace(os.sep, "/")
                    zf.write(full, arcname=arc)
                for d in dirnames:
                    full = os.path.join(dirpath, d)
                    if not os.listdir(full):  # 保留空目录
                        rel = os.path.relpath(full, source)
                        arc = (os.path.join(root_name, rel) + "/").replace(os.sep, "/")
                        zf.writestr(zipfile.ZipInfo(arc), b"")

    return root_type, root_name, buf.getvalue()


def _is_safe_member(member_name: str, output_dir: str) -> str:
    """检查 ZIP 成员不会越界（Zip Slip 防护），返回安全的绝对目标路径。"""
    if member_name.startswith(("/", "\\")) or os.path.isabs(member_name):
        raise InvalidPackageError("加密包内含非法的绝对路径。")
    normalized = os.path.normpath(member_name)
    if normalized == ".." or normalized.startswith(".." + os.sep):
        raise InvalidPackageError("加密包内含越界的相对路径。")

    target = os.path.abspath(os.path.join(output_dir, member_name.replace("/", os.sep)))
    base = os.path.abspath(output_dir)
    if os.path.commonpath([base, target]) != base:
        raise InvalidPackageError("加密包内路径试图跳出输出目录。")
    return target


def _extract_archive(blob: bytes, output_dir: str) -> list[str]:
    written: list[str] = []
    with zipfile.ZipFile(io.BytesIO(blob)) as zf:
        for member in zf.infolist():
            target = _is_safe_member(member.filename, output_dir)
            if member.is_dir():
                os.makedirs(target, exist_ok=True)
                continue
            os.makedirs(os.path.dirname(target), exist_ok=True)
            if os.path.exists(target):  # 防御性：绝不覆盖
                raise OutputExistsError(f"输出位置已存在同名文件：{member.filename}")
            with zf.open(member) as src, open(target, "wb") as dst:
                dst.write(src.read())
            written.append(target)
    return written


# --------------------------------------------------------------------------- #
# 容器读写
# --------------------------------------------------------------------------- #
def _build_container(header: dict, payload: bytes) -> bytes:
    header_bytes = json.dumps(
        header, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    return (
        MAGIC
        + bytes([FORMAT_VERSION])
        + struct.pack(">I", len(header_bytes))
        + header_bytes
        + struct.pack(">I", len(payload))
        + payload
    )


def _parse_container(raw: bytes) -> tuple[dict, bytes]:
    prefix_len = len(MAGIC) + 1 + 4
    if len(raw) < prefix_len or raw[: len(MAGIC)] != MAGIC:
        raise InvalidPackageError("不是本工具生成的加密包（魔数不匹配）。")
    if raw[len(MAGIC)] != FORMAT_VERSION:
        raise InvalidPackageError("不支持的加密包版本。")

    header_len = struct.unpack(">I", raw[len(MAGIC) + 1 : prefix_len])[0]
    header_bytes = raw[prefix_len : prefix_len + header_len]
    if len(header_bytes) != header_len:
        raise InvalidPackageError("加密包头部不完整。")
    try:
        header = json.loads(header_bytes.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise InvalidPackageError("加密包头部无法解析。") from exc

    offset = prefix_len + header_len
    if len(raw) < offset + 4:
        raise InvalidPackageError("加密包缺少数据长度。")
    payload_len = struct.unpack(">I", raw[offset : offset + 4])[0]
    payload = raw[offset + 4 : offset + 4 + payload_len]
    if len(payload) != payload_len or offset + 4 + payload_len != len(raw):
        raise InvalidPackageError("加密包数据不完整或含多余字节。")
    return header, payload


# --------------------------------------------------------------------------- #
# 对外接口
# --------------------------------------------------------------------------- #
def validate_inputs(
    file_password: str,
    recovery_password: str | None = None,
    hint: str | None = None,
) -> None:
    """供界面在加密前做即时校验；不通过即抛 ValidationError。"""
    if not file_password:
        raise ValidationError("文件密码不能为空。")
    if recovery_password:
        if recovery_password == file_password:
            raise ValidationError("恢复密码必须与文件密码不同。")
    if hint:
        if hint == file_password:
            raise ValidationError("提示为可见字段，不能与文件密码相同。")
        if recovery_password and hint == recovery_password:
            raise ValidationError("提示为可见字段，不能与恢复密码相同。")


def encrypt_path(
    source_path: str,
    output_package_path: str,
    file_password: str,
    hint: str | None = None,
    recovery_password: str | None = None,
) -> str:
    """加密单个文件或文件夹，返回写出的加密包路径。原件保留。"""
    validate_inputs(file_password, recovery_password, hint)

    output_package_path = os.path.abspath(output_package_path)
    if os.path.exists(output_package_path):
        raise OutputExistsError("输出位置已存在同名加密包，请更换名称或位置。")

    root_type, root_name, archive_bytes = _build_archive(source_path)

    want_recovery = bool(recovery_password)
    cek = os.urandom(KEY_LEN)

    # 先组装不含密文的头部骨架，再用其 AAD 完成各层加密
    header: dict = {
        "format": FORMAT_VERSION,
        "kdf": "scrypt",
        "kdf_params": KDF_PARAMS,
        "root_type": root_type,
        "root_name": root_name,
        "hint": hint or "",
        "file": {
            "salt": _b64e(os.urandom(SALT_LEN)),
            "nonce": _b64e(os.urandom(NONCE_LEN)),
        },
        "recovery": None,
        "payload": {"nonce": _b64e(os.urandom(NONCE_LEN))},
    }
    if want_recovery:
        header["recovery"] = {
            "salt": _b64e(os.urandom(SALT_LEN)),
            "nonce": _b64e(os.urandom(NONCE_LEN)),
        }

    aad = _aad_from_header(header)

    # 文件密码路径封装 CEK
    file_salt = _b64d(header["file"]["salt"])
    file_kek = _derive_key(file_password, file_salt, KDF_PARAMS)
    file_nonce = _b64d(header["file"]["nonce"])
    header["file"]["wrapped"] = _b64e(
        AESGCM(file_kek).encrypt(file_nonce, cek, aad)
    )

    # 恢复密码路径封装同一个 CEK（独立 salt/nonce）
    if want_recovery:
        rec_salt = _b64d(header["recovery"]["salt"])
        rec_kek = _derive_key(recovery_password, rec_salt, KDF_PARAMS)
        rec_nonce = _b64d(header["recovery"]["nonce"])
        header["recovery"]["wrapped"] = _b64e(
            AESGCM(rec_kek).encrypt(rec_nonce, cek, aad)
        )

    # 用 CEK 加密归档数据
    payload_nonce = _b64d(header["payload"]["nonce"])
    payload_cipher = AESGCM(cek).encrypt(payload_nonce, archive_bytes, aad)

    container = _build_container(header, payload_cipher)

    # 写盘前再次确认，避免竞态下覆盖
    if os.path.exists(output_package_path):
        raise OutputExistsError("输出位置已存在同名加密包，请更换名称或位置。")
    parent = os.path.dirname(output_package_path)
    os.makedirs(parent, exist_ok=True)
    with open(output_package_path, "wb") as f:
        f.write(container)
    return output_package_path


def read_package_info(package_path: str) -> dict:
    """不解密，只读取提示与是否启用恢复等信息，供界面在输入密码前展示。"""
    with open(package_path, "rb") as f:
        raw = f.read()
    header, _ = _parse_container(raw)
    return {
        "hint": header.get("hint", ""),
        "recovery_enabled": header.get("recovery") is not None,
        "root_type": header.get("root_type"),
        "root_name": header.get("root_name"),
    }


def decrypt_package(
    package_path: str,
    password: str,
    output_dir: str,
    use_recovery: bool = False,
) -> str:
    """解密/恢复加密包到输出目录，返回输出目录绝对路径。

    认证全部通过后才创建目录并写文件；任何失败都不会落盘。
    """
    with open(package_path, "rb") as f:
        raw = f.read()
    header, payload_cipher = _parse_container(raw)
    aad = _aad_from_header(header)

    if use_recovery:
        block = header.get("recovery")
        if block is None:
            raise RecoveryNotEnabledError("该加密包在加密时未启用恢复，无法用恢复密码打开。")
        fail_message = "恢复密码错误，无法打开。"
    else:
        block = header["file"]
        fail_message = "文件密码错误，无法打开。"

    salt = _b64d(block["salt"])
    nonce = _b64d(block["nonce"])
    wrapped = _b64d(block["wrapped"])
    kek = _derive_key(password, salt, header["kdf_params"])

    try:
        cek = AESGCM(kek).decrypt(nonce, wrapped, aad)
    except InvalidTag as exc:
        raise WrongPasswordError(fail_message) from exc

    payload_nonce = _b64d(header["payload"]["nonce"])
    try:
        archive_bytes = AESGCM(cek).decrypt(payload_nonce, payload_cipher, aad)
    except InvalidTag as exc:
        raise InvalidPackageError("数据认证失败，加密包可能已损坏或被篡改。") from exc

    # 到这里认证已全部通过，才开始处理输出目录与落盘
    output_dir = os.path.abspath(output_dir)
    if os.path.exists(output_dir):
        if not os.path.isdir(output_dir):
            raise OutputExistsError("输出路径已被一个文件占用，请更换位置。")
        if os.listdir(output_dir):
            raise NonEmptyDirectoryError("输出目录非空，请选择空目录或新建目录。")
    else:
        os.makedirs(output_dir)

    _extract_archive(archive_bytes, output_dir)
    return output_dir
