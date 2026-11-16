"""程序入口：启动本地文件加密工具的桌面窗口。

运行方式（在项目目录下）：
    .venv\\Scripts\\python.exe main.py
"""

from __future__ import annotations

import tkinter as tk

from ui import EncryptionApp


def main() -> None:
    root = tk.Tk()
    EncryptionApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
