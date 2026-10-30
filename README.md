### What is honest-mintify?


`honest-mintify` is a bash script created with the help of Qwen3-255B and Claude 4.8 Opus. It is designed to automate the setup process for Linux Mint to make it easier for the technologically challenged to use it for their day-to-day life.

### Why?
I created this script for Honest Repair, my phone/computer repair shop located in Fenton, Missouri. It is tailored towards my needs only. I am open-sourcing it because I believe in FOSS, and I want to be transparent with what scripts I run on customer devices.

Note: DO NOT RUN RANDOM SCRIPTS OFF THE INTERNET, PLEASE LOOK OVER THE SCRIPT FIRST BEFORE RUNNING IT FOR YOUR OWN SECURITY!
### Features
* Removes unnecessary applications, specifically Element, Hypnotix, Transmission, and Thunderbird. This is done in an attempt to minimize confusion for the technologically challenged.
* Configures DNS-over-HTTPS via [AdGuard Public DNS](https://adguard-dns.io/en/public-dns.html) for enhanced privacy.
* Optionally allows you to replace LibreOffice with ONLYOFFICE (downloaded from Flathub).
* Optionally allows you to replace Firefox with Brave Origin (using official installation script)
### Usage
1. Download `honest-mintify`.
2. Allow it to be ran as a program:
```
chmod +x honest-mintify.sh
```
3. Run the script using:
```
sudo ./honest-mintify.sh
```
Or you can use `curl` to run the script directly from this repo on any Internet connected device:
```
curl -sL https://raw.githubusercontent.com/candroid-man/honest-mintify/main/honest-mintify.sh | sudo bash -
```
### Switching from Mullvad DNS to AdGuard DNS
Mullvad's public DNS is shutting down. PCs set up with older versions of this script have Mullvad DNS built in and will stop loading websites once it's gone. `fix-dns.sh` removes Mullvad and switches them to AdGuard DNS-over-TLS (same setup as the main script). It doesn't touch anything else, and it won't reboot.

Paste this into a terminal (it asks for the computer's password; nothing shows on screen while typing it, that's normal):
```
curl -fsSL https://raw.githubusercontent.com/candroid-man/honest-mintify/main/fix-dns.sh | sudo bash
```
If the PC already can't load websites (Mullvad is already gone), use this one instead. It connects to GitHub by IP address, so it works without DNS:
```
curl -fsSL --resolve raw.githubusercontent.com:443:185.199.108.133 https://raw.githubusercontent.com/candroid-man/honest-mintify/main/fix-dns.sh | sudo bash
```
When it finishes it says `DONE: internet is working`. If the network blocks encrypted DNS, it falls back to AdGuard over regular DNS so the PC stays online.
### Contributing/Forking
Feel free to contribute if you want if you can find something to make it better at what it already does, and do whatever you want with this script, I really don't care.
