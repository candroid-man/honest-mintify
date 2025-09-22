### What is HonestMintify?
HonestMintify is a script created with the help of the Qwen3-255B (Reasoning) LLM. It is designed to automate my entire setup process for those who pay me to install Linux Mint on their device.
### Why?
I created this script for Honest Repair, my phone/computer repair shop located in Fenton, Missouri. It is tailored towards my needs only. I am open-sourcing it because I believe in FOSS, and I want to be transparent with what scripts I run on customer devices.
### Features
* Removes unnecessary applications, specifically Element, Hypnotix, and Thunderbird. This is done in an attempt to minimize confusion for the technologically challenged.
* Configures Mullvad DNS with DNS-over-TLS for enhanced privacy.
* Optionally allows you to replace LibreOffice with ONLYOFFICE (downloaded from Flathub).
* Optionally allows you to replace Firefox with Brave (using official installation script) along with a custom management policy that removes undesirable settings.
### Usage
1. Download both `honest-mintify` and `policy.json`, keep them in the same directory.
2. Allow it to be ran as a program:
```
chmod +x system-cleaner.sh
```
3. Run the script using:
```
sudo ./system-cleaner.sh
```
Or you can use `curl` to run the script directly from this repo on any Internet connected device:
```
curl -sL https://raw.githubusercontent.com/candroid-man/HonestMintify/main/honest-mintify.sh | sudo bash -
```
### Contributing/Forking
Feel free to contribute if you want if you can find something to make it better at what it already does, and do whatever you want with this script, I really don't care.















