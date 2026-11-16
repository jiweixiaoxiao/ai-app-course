"""tkinter 桌面界面：手动选择对象、掩码输入密码、查看提示、加密/解密/恢复。

界面只负责收集输入与展示结果，所有加解密与安全校验都在 crypto_core 中完成。
密码输入框一律掩码；提示区域明确标注“可见”；任何密码都不写入日志或界面外的地方。
"""

from __future__ import annotations

import os
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

import crypto_core

PACKAGE_EXT = ".pyenc"
PACKAGE_FILETYPES = [("加密包", f"*{PACKAGE_EXT}"), ("所有文件", "*.*")]


class EncryptionApp:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        root.title("此地无银")
        icon_path = os.path.join(
            os.path.dirname(os.path.abspath(__file__)), "assets", "app.ico"
        )
        if os.path.exists(icon_path):
            root.iconbitmap(default=icon_path)
        root.minsize(560, 480)

        self.notebook = ttk.Notebook(root)
        self.notebook.pack(fill="both", expand=True, padx=10, pady=10)

        self._build_encrypt_tab()
        self._build_decrypt_tab()

    # ------------------------------------------------------------------ #
    # 加密页
    # ------------------------------------------------------------------ #
    def _build_encrypt_tab(self) -> None:
        tab = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(tab, text="加密")

        self.enc_source = tk.StringVar()
        self.enc_output = tk.StringVar()
        self.enc_hint = tk.StringVar()
        self.enc_password = tk.StringVar()
        self.enc_password2 = tk.StringVar()
        self.enable_recovery = tk.BooleanVar(value=False)
        self.enc_rec_password = tk.StringVar()
        self.enc_rec_password2 = tk.StringVar()

        row = 0
        ttk.Label(tab, text="1. 选择要加密的对象（单个文件或文件夹）").grid(
            row=row, column=0, columnspan=3, sticky="w", pady=(0, 4)
        )
        row += 1
        ttk.Entry(tab, textvariable=self.enc_source, width=52).grid(
            row=row, column=0, columnspan=2, sticky="we"
        )
        ttk.Button(tab, text="选择文件", command=self._pick_enc_file).grid(
            row=row, column=2, padx=(6, 0)
        )
        row += 1
        ttk.Button(tab, text="选择文件夹", command=self._pick_enc_folder).grid(
            row=row, column=2, sticky="e", padx=(6, 0), pady=(4, 0)
        )

        row += 2
        ttk.Label(tab, text="2. 设置文件密码（输入已遮挡）").grid(
            row=row, column=0, columnspan=3, sticky="w", pady=(8, 4)
        )
        row += 1
        ttk.Label(tab, text="文件密码").grid(row=row, column=0, sticky="w")
        ttk.Entry(tab, textvariable=self.enc_password, show="*", width=28).grid(
            row=row, column=1, sticky="w"
        )
        row += 1
        ttk.Label(tab, text="再次输入").grid(row=row, column=0, sticky="w")
        ttk.Entry(tab, textvariable=self.enc_password2, show="*", width=28).grid(
            row=row, column=1, sticky="w"
        )

        row += 2
        ttk.Label(tab, text="3. 提示（可选，字段可见，请勿填写任何密码）").grid(
            row=row, column=0, columnspan=3, sticky="w", pady=(8, 4)
        )
        row += 1
        ttk.Entry(tab, textvariable=self.enc_hint, width=52).grid(
            row=row, column=0, columnspan=2, sticky="we"
        )

        row += 2
        ttk.Checkbutton(
            tab,
            text="4. 启用恢复（另设独立的恢复密码）",
            variable=self.enable_recovery,
            command=self._toggle_recovery,
        ).grid(row=row, column=0, columnspan=3, sticky="w", pady=(8, 4))
        row += 1
        self.rec_pw_label = ttk.Label(tab, text="恢复密码")
        self.rec_pw_label.grid(row=row, column=0, sticky="w")
        self.rec_pw_entry = ttk.Entry(
            tab, textvariable=self.enc_rec_password, show="*", width=28, state="disabled"
        )
        self.rec_pw_entry.grid(row=row, column=1, sticky="w")
        row += 1
        self.rec_pw2_label = ttk.Label(tab, text="再次输入")
        self.rec_pw2_label.grid(row=row, column=0, sticky="w")
        self.rec_pw2_entry = ttk.Entry(
            tab, textvariable=self.enc_rec_password2, show="*", width=28, state="disabled"
        )
        self.rec_pw2_entry.grid(row=row, column=1, sticky="w")

        row += 2
        ttk.Label(tab, text="5. 选择加密包输出位置（原件会保留）").grid(
            row=row, column=0, columnspan=3, sticky="w", pady=(8, 4)
        )
        row += 1
        ttk.Entry(tab, textvariable=self.enc_output, width=52).grid(
            row=row, column=0, columnspan=2, sticky="we"
        )
        ttk.Button(tab, text="选择位置", command=self._pick_enc_output).grid(
            row=row, column=2, padx=(6, 0)
        )

        row += 2
        ttk.Button(tab, text="开始加密", command=self._do_encrypt).grid(
            row=row, column=0, columnspan=3, pady=(12, 0)
        )

        tab.columnconfigure(1, weight=1)

    def _toggle_recovery(self) -> None:
        state = "normal" if self.enable_recovery.get() else "disabled"
        self.rec_pw_entry.configure(state=state)
        self.rec_pw2_entry.configure(state=state)

    def _pick_enc_file(self) -> None:
        path = filedialog.askopenfilename(title="选择要加密的文件")
        if path:
            self.enc_source.set(path)

    def _pick_enc_folder(self) -> None:
        path = filedialog.askdirectory(title="选择要加密的文件夹")
        if path:
            self.enc_source.set(path)

    def _pick_enc_output(self) -> None:
        path = filedialog.asksaveasfilename(
            title="选择加密包输出位置",
            defaultextension=PACKAGE_EXT,
            filetypes=PACKAGE_FILETYPES,
        )
        if path:
            self.enc_output.set(path)

    def _do_encrypt(self) -> None:
        source = self.enc_source.get().strip()
        output = self.enc_output.get().strip()
        pw = self.enc_password.get()
        pw2 = self.enc_password2.get()
        hint = self.enc_hint.get().strip()

        if not source:
            messagebox.showwarning("缺少对象", "请先选择要加密的文件或文件夹。")
            return
        if not output:
            messagebox.showwarning("缺少输出", "请选择加密包的输出位置。")
            return
        if not pw:
            messagebox.showwarning("缺少密码", "请设置文件密码。")
            return
        if pw != pw2:
            messagebox.showerror("密码不一致", "两次输入的文件密码不一致，请重新输入。")
            return

        recovery_password = None
        if self.enable_recovery.get():
            rec_pw = self.enc_rec_password.get()
            rec_pw2 = self.enc_rec_password2.get()
            if not rec_pw:
                messagebox.showwarning("缺少恢复密码", "已启用恢复，请设置恢复密码。")
                return
            if rec_pw != rec_pw2:
                messagebox.showerror("恢复密码不一致", "两次输入的恢复密码不一致。")
                return
            recovery_password = rec_pw

        try:
            result = crypto_core.encrypt_path(
                source_path=source,
                output_package_path=output,
                file_password=pw,
                hint=hint or None,
                recovery_password=recovery_password,
            )
        except crypto_core.CryptoToolError as exc:
            messagebox.showerror("加密失败", str(exc))
            return
        except Exception as exc:  # 防止界面崩溃，不展示任何密码
            messagebox.showerror("发生意外错误", f"操作未完成：{exc}")
            return

        messagebox.showinfo(
            "加密完成",
            f"加密包已生成：\n{result}\n\n原件已保留，未被修改或删除。",
        )

    # ------------------------------------------------------------------ #
    # 解密 / 恢复页
    # ------------------------------------------------------------------ #
    def _build_decrypt_tab(self) -> None:
        tab = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(tab, text="解密 / 恢复")

        self.dec_package = tk.StringVar()
        self.dec_output = tk.StringVar()
        self.dec_password = tk.StringVar()
        self.dec_mode = tk.StringVar(value="file")
        self.dec_info_var = tk.StringVar(value="（尚未读取加密包信息）")

        row = 0
        ttk.Label(tab, text="1. 选择加密包").grid(
            row=row, column=0, columnspan=3, sticky="w", pady=(0, 4)
        )
        row += 1
        ttk.Entry(tab, textvariable=self.dec_package, width=52).grid(
            row=row, column=0, columnspan=2, sticky="we"
        )
        ttk.Button(tab, text="选择加密包", command=self._pick_dec_package).grid(
            row=row, column=2, padx=(6, 0)
        )

        row += 2
        ttk.Label(tab, text="2. 提示（输入密码前可查看）").grid(
            row=row, column=0, columnspan=3, sticky="w", pady=(8, 4)
        )
        row += 1
        ttk.Label(tab, text="提示可见", foreground="#b00000").grid(
            row=row, column=0, sticky="w"
        )
        ttk.Label(tab, textvariable=self.dec_info_var, wraplength=420).grid(
            row=row, column=1, columnspan=2, sticky="w"
        )
        row += 1
        ttk.Button(tab, text="读取提示/信息", command=self._read_info).grid(
            row=row, column=0, sticky="w", pady=(4, 0)
        )

        row += 2
        ttk.Label(tab, text="3. 选择解锁方式").grid(
            row=row, column=0, columnspan=3, sticky="w", pady=(8, 4)
        )
        row += 1
        ttk.Radiobutton(
            tab, text="用文件密码解密", variable=self.dec_mode, value="file"
        ).grid(row=row, column=0, columnspan=2, sticky="w")
        row += 1
        ttk.Radiobutton(
            tab, text="用恢复密码恢复（仅对启用恢复的包有效）",
            variable=self.dec_mode, value="recovery",
        ).grid(row=row, column=0, columnspan=2, sticky="w")

        row += 2
        ttk.Label(tab, text="4. 输入密码（输入已遮挡）").grid(
            row=row, column=0, columnspan=3, sticky="w", pady=(8, 4)
        )
        row += 1
        ttk.Entry(tab, textvariable=self.dec_password, show="*", width=32).grid(
            row=row, column=0, columnspan=2, sticky="w"
        )

        row += 2
        ttk.Label(tab, text="5. 选择输出目录（空目录或新建目录）").grid(
            row=row, column=0, columnspan=3, sticky="w", pady=(8, 4)
        )
        row += 1
        ttk.Entry(tab, textvariable=self.dec_output, width=52).grid(
            row=row, column=0, columnspan=2, sticky="we"
        )
        ttk.Button(tab, text="选择目录", command=self._pick_dec_output).grid(
            row=row, column=2, padx=(6, 0)
        )

        row += 2
        ttk.Button(tab, text="开始解密 / 恢复", command=self._do_decrypt).grid(
            row=row, column=0, columnspan=3, pady=(12, 0)
        )

        tab.columnconfigure(1, weight=1)

    def _pick_dec_package(self) -> None:
        path = filedialog.askopenfilename(
            title="选择加密包", filetypes=PACKAGE_FILETYPES
        )
        if path:
            self.dec_package.set(path)
            self.dec_info_var.set("（已选择，点击“读取提示/信息”查看）")

    def _read_info(self) -> None:
        package = self.dec_package.get().strip()
        if not package:
            messagebox.showwarning("缺少加密包", "请先选择加密包。")
            return
        try:
            info = crypto_core.read_package_info(package)
        except crypto_core.CryptoToolError as exc:
            messagebox.showerror("无法读取", str(exc))
            return
        hint = info["hint"] or "（该包没有提示）"
        rec = "已启用恢复" if info["recovery_enabled"] else "未启用恢复"
        self.dec_info_var.set(f"{hint}    ［{rec}］")

    def _pick_dec_output(self) -> None:
        path = filedialog.askdirectory(title="选择空目录或新建输出目录")
        if path:
            self.dec_output.set(path)

    def _do_decrypt(self) -> None:
        package = self.dec_package.get().strip()
        password = self.dec_password.get()
        output = self.dec_output.get().strip()
        use_recovery = self.dec_mode.get() == "recovery"

        if not package:
            messagebox.showwarning("缺少加密包", "请先选择加密包。")
            return
        if not password:
            messagebox.showwarning("缺少密码", "请输入密码。")
            return
        if not output:
            messagebox.showwarning("缺少输出目录", "请选择输出目录。")
            return

        try:
            result = crypto_core.decrypt_package(
                package_path=package,
                password=password,
                output_dir=output,
                use_recovery=use_recovery,
            )
        except crypto_core.RecoveryNotEnabledError as exc:
            messagebox.showerror("无法恢复", str(exc))
            return
        except crypto_core.CryptoToolError as exc:
            messagebox.showerror("解密失败", str(exc))
            return
        except Exception as exc:
            messagebox.showerror("发生意外错误", f"操作未完成：{exc}")
            return

        messagebox.showinfo(
            "解密完成",
            f"文件已还原到：\n{result}\n\n未写出任何原文件密码。",
        )
