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
curl -sL https://raw.githubusercontent.com/candroid-man/HonestMintify/main/honest-mintify.sh | sudo bash -
```
### Contributing/Forking
Feel free to contribute if you want if you can find something to make it better at what it already does, and do whatever you want with this script, I really don't care.
