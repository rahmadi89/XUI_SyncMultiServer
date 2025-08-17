# XUI Sync Multi Server

This script is designed to **synchronize user traffic and quota** across multiple **x-ui** servers.  
If a user has more traffic usage or a larger total quota on one server, the script will propagate the same changes to all other servers.  

⚡ **Important:** The script must be installed on **every server** to work properly.

Tested on 
- [x] Ubuntu 22.04


## 🚀 Installation

Run the following command on each server:

```bash
bash <(curl -Ls "https://raw.githubusercontent.com/rahmadi89/XUI_SyncMultiServer/main/install.sh")
```

## 🗑️ Uninstall
To remove the script, run:

```bash
bash <(curl -Ls "https://raw.githubusercontent.com/rahmadi89/XUI_SyncMultiServer/main/install.sh") --uninstall
```


فارسی 🇮🇷

این اسکریپت برای همگام‌سازی حجم کاربران در چندین سرور x-ui طراحی شده است.
اگر کاربری در یکی از سرورها مصرف یا حجم کل بیشتری داشته باشد، اسکریپت این تغییرات را روی تمام سرورها همگام می‌کند.

⚡ نکته مهم: این اسکریپت باید روی تک‌تک سرورها نصب شود تا همگام‌سازی به درستی انجام شود.

## 🚀 نصب
```bash
bash <(curl -Ls "https://raw.githubusercontent.com/rahmadi89/XUI_SyncMultiServer/main/install.sh")
```

## 🗑️ حذف
```bash
bash <(curl -Ls "https://raw.githubusercontent.com/rahmadi89/XUI_SyncMultiServer/main/install.sh") --uninstall
```

## TODO

- [x] Write Read me in both english and persian
- [x] Check login at install time and the add config
- [ ] Encrypt passwords saved in servers.json
