### What is honest-mintify?


`honest-mintify` is a script created with the help of the Qwen3-255B (Reasoning) LLM. It is designed to automate the setup process for Linux Mint to make it easier for the technologically challenged to use it for their day-to-day life.

### Why?
I created this script for Honest Repair, my phone/computer repair shop located in Fenton, Missouri. It is tailored towards my needs only. I am open-sourcing it because I believe in FOSS, and I want to be transparent with what scripts I run on customer devices.
### Features
* Removes unnecessary applications, specifically Element (`mintchat`), Hypnotix, and Thunderbird. This is done in an attempt to minimize confusion for the technologically challenged.
* Configures [Mullvad DNS with DNS-over-TLS](https://mullvad.net/en/help/dns-over-https-and-dns-over-tls#linux) for enhanced privacy.
* Optionally allows you to replace LibreOffice with ONLYOFFICE (downloaded from Flathub).
* Optionally allows you to replace Firefox with Brave (using official installation script) along with a custom management policy that removes/changes undesirable settings such as:
  * Web3
  * Rewards
  * Tor
  * AI features
  * Advertisements (Talk, VPN, Leo, etc.)
  * Telemetry (WIP)
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

### Credits
[brave-debloatinator by MulesGaming](https://github.com/MulesGaming/brave-debloatinator) was SUPER helpful. It helped me create the Brave policy and the Brave portion of the script that copies `policy.json` to the correct place on Linux systems.
