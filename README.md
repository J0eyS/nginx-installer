# NGINX Auto-Installer

This project provides simple, streamlined scripts to **install or uninstall NGINX** on multiple Linux distributions: Ubuntu, Debian, CentOS/Rocky/AlmaLinux, and Alpine Linux.  
Each script detects your OS version, configures NGINX with a default website for your domain, and optionally sets up free SSL certificates with Certbot (except Alpine, which currently skips SSL).

---

## Quick Install Commands

### Ubuntu  
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/J0eyS/nginx-installer/main/install.sh)
```

### Debian  
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/J0eyS/nginx-installer/main/install-debian.sh)
```


### CentOS / Rocky / AlmaLinux  
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/J0eyS/nginx-installer/main/install-centos.sh)
```

### Alpine Linux 
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/J0eyS/nginx-installer/main/install-alpine.sh)
```

---

## Features

- Detects your operating system and version automatically  
- Installs and configures NGINX with a ready-to-use server block  
- Creates a sample website root directory for your domain  
- Optionally installs free SSL certificates using Certbot (Ubuntu, Debian, CentOS)  
- Provides an uninstall option to cleanly remove NGINX and related files  
- Menu-driven interface for easy use  

---

## Notes

- Make sure your domain's DNS records point to this server before requesting SSL certificates.  
- Port 80 must be open and accessible for Certbot validation.  
- Run the scripts as root or with sudo.  

---

## AI

 This installer script and/or the description was created with the help of AI tools.

---

## Contributing

Contributions and feedback are welcome! Feel free to open issues or submit pull requests to improve support or add features.


