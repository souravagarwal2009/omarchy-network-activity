# omarchy-network-activity

Real-time network bandwidth monitor and traffic history plugin for the [Omarchy](https://omarchy.org) shell (Quickshell).

![Network Activity Widget Preview](https://raw.githubusercontent.com/souravagarwal2009/omarchy-network-activity/master/preview.png)

## Features

- **Live Speed Display**: Shows current download and upload speeds directly in the top status bar.
- **Traffic History Graph**: Interactive popup panel featuring real-time bandwidth graphs.
- **Lightweight & Fast**: Direct `/proc/net/dev` polling with minimal CPU and memory overhead.
- **Adaptive Units**: Auto-scales between B/s, KB/s, MB/s, and GB/s.

## Installation

### Using Omarchy Plugin Directory

1. Clone this repository into your Omarchy plugins directory:
   ```bash
   git clone https://github.com/souravagarwal2009/omarchy-network-activity.git ~/.config/omarchy/plugins/custom.network-activity
   ```

2. Reload Omarchy shell or rescan plugins:
   ```bash
   omarchy restart shell
   ```

3. Add the widget to your bar layout in `~/.config/omarchy/shell.json` or via:
   ```bash
   omarchy bar add custom.network-activity --section left
   ```

## License

MIT License. See [LICENSE](LICENSE) for details.
