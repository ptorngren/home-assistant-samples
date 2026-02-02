# Home Assistant Samples

Some Home Assistant examples and experiments that might be generally useful. Use freely, adapt as needed — no guarantees.

## Projects

### [Screensaver](./screensaver/)
Wall panel screensaver dashboard with weather display, anti-burn-in animations, and tap actions for Home Assistant.

### More?
I've also been playing with setting up Home Assistant for my Yamaha MusicCast multi-room audio system and scheduling the car heaters. 
Hope to publish these samples as well after some polishing.

## Environment & Context

The examples originate from my Home Assistant setup:

- **Shelly devices** — ~30 smart plugs, relays, and buttons, primarily for lighting control and car heaters
- **Zigbee devices** — light sensors
- **Yamaha MusicCast** — ~20 multi-room audio devices, some configured as stereo pairs  
- **LVI / Purmo Unisenza** — ~5 digital heat radiators  
- **Netatmo Weather Stations** — one facing east (morning sun), one facing west (evening sun), one windspeed, two units indoor
- **Verisure alarm system** — includes climate sensors
- **IVT / WiHeat heat pump** — partially integrated  
- **Google Cast** — Android TV, Google TV, Chromecast devices  
- **Harvia sauna** — unfortunately hard to integrate
- **Mobile devices** — Android and Apple tablets and phones
- **Computers** — Windows laptops and desktops, Ubuntu file and music server
- **UniFi video doorbell**

**Infrastructure:**
- **Nabu Casa** — remote access to Home Assistant  
- **Raspberry Pi** — running HAOS  
- **Ubiquiti UniFi** — network with two access points  
- **Devolo Powerline** — extending LAN where Wi-Fi coverage is poor  

Not all projects depend on all of these components.

## About This Project

This project represents an experiment in learning YAML and the Home Assistant ecosystem; 
as a long-time (now retired) software developer, I found the learning threshold rather steep.
While experienced in traditional programming, the Home Assistant domain is new territory, 
particularly its YAML configuration language, templating patterns, and HACS components.

Rather than learning entirely through trial-and-error, this project was developed with heavy 
reliance on AI tools to accelerate learning and code generation:

- **Claude Code** — Primary development tool with Home Assistant MCP integration and IntelliJ IDEA plugin
- **Gemini** — Supplementary tool for specific technical questions and alternative approaches
- **ChatGPT** — for a second opinion and review, especially texts.
- **Github Copilot** — initially used for coding in VS Code until replaced by Claude Code in IntelliJ

This approach allowed rapid prototyping and iteration while focusing intellectual energy on architecture and design rather than language syntax. 
The AI tools acted as accelerators and collaborators, not replacements for design thinking or testing.
It's been an interesting experiment in blending human creativity with AI assistance in software development, 
and I must say the results have been impressive! All the fun of coding, with most of the tedious typing and syntax errors eliminated.

**Note:** All code has been reviewed and tested "in production" (at home), but I do not claim that it works for you. 
None of this should be considered a product, but rather a shared experience that may inspire fellow automators. Or the opposite ;-)

Questions or suggestions? Open a GitHub issue! 

## License

MIT License — See LICENSE file for details
