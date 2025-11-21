#!/usr/bin/env python3
"""
X/Twitter → xcancel Setup Wizard
Interactive configuration generator for the redirect proxy
"""

import os
import sys
import subprocess
import shutil
import re
from pathlib import Path
from typing import Optional, List, Dict

# ANSI color codes
class Colors:
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BOLD = '\033[1m'
    END = '\033[0m'

def print_header(text: str):
    """Print a section header"""
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{text:^60}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}\n")

def print_success(text: str):
    """Print success message"""
    print(f"{Colors.GREEN}✓{Colors.END} {text}")

def print_error(text: str):
    """Print error message"""
    print(f"{Colors.RED}✗{Colors.END} {text}")

def print_warning(text: str):
    """Print warning message"""
    print(f"{Colors.YELLOW}⚠{Colors.END} {text}")

def print_info(text: str):
    """Print info message"""
    print(f"{Colors.BLUE}ℹ{Colors.END} {text}")

def ask_question(question: str, options: List[str], default: Optional[str] = None) -> str:
    """Ask a multiple choice question"""
    print(f"\n{Colors.BOLD}{question}{Colors.END}")
    for i, option in enumerate(options, 1):
        default_marker = " (default)" if default and option == default else ""
        print(f"  {i}. {option}{default_marker}")

    while True:
        try:
            choice = input(f"\nEnter choice [1-{len(options)}]: ").strip()
            if not choice and default:
                return default
            choice_num = int(choice)
            if 1 <= choice_num <= len(options):
                return options[choice_num - 1]
            print_error(f"Please enter a number between 1 and {len(options)}")
        except (ValueError, KeyboardInterrupt):
            print_error("Invalid input")

def ask_text(question: str, default: Optional[str] = None, validator=None) -> str:
    """Ask a text question"""
    default_text = f" [{default}]" if default else ""
    while True:
        answer = input(f"{Colors.BOLD}{question}{Colors.END}{default_text}: ").strip()
        if not answer and default:
            return default
        if validator:
            valid, msg = validator(answer)
            if not valid:
                print_error(msg)
                continue
        if answer:
            return answer
        print_error("Please provide an answer")

def ask_yes_no(question: str, default: bool = True) -> bool:
    """Ask a yes/no question"""
    default_text = "Y/n" if default else "y/N"
    answer = input(f"{Colors.BOLD}{question}{Colors.END} [{default_text}]: ").strip().lower()
    if not answer:
        return default
    return answer in ['y', 'yes']

def validate_ip(ip: str) -> tuple[bool, str]:
    """Validate IP address"""
    pattern = r'^(\d{1,3}\.){3}\d{1,3}$'
    if not re.match(pattern, ip):
        return False, "Invalid IP address format"
    parts = ip.split('.')
    if any(int(p) > 255 for p in parts):
        return False, "IP address octets must be 0-255"
    return True, ""

def validate_port(port: str) -> tuple[bool, str]:
    """Validate port number"""
    try:
        p = int(port)
        if 1 <= p <= 65535:
            return True, ""
        return False, "Port must be between 1-65535"
    except ValueError:
        return False, "Port must be a number"

def check_command(cmd: str) -> bool:
    """Check if a command is available"""
    return shutil.which(cmd) is not None

def detect_network_interface() -> Optional[str]:
    """Detect primary network interface"""
    try:
        if sys.platform == 'darwin':  # macOS
            result = subprocess.run(
                ['route', 'get', 'default'],
                capture_output=True, text=True
            )
            for line in result.stdout.split('\n'):
                if 'interface:' in line:
                    return line.split(':')[1].strip()
        else:  # Linux
            result = subprocess.run(
                ['ip', 'route', 'show', 'default'],
                capture_output=True, text=True
            )
            if result.stdout:
                parts = result.stdout.split()
                if 'dev' in parts:
                    idx = parts.index('dev')
                    if idx + 1 < len(parts):
                        return parts[idx + 1]
    except:
        pass
    return None

def detect_local_ip() -> Optional[str]:
    """Detect local IP address"""
    try:
        import socket
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        return local_ip
    except:
        return None

class SetupWizard:
    def __init__(self):
        self.config = {}
        self.project_dir = Path(__file__).parent.parent
        self.has_docker = check_command('docker')
        self.has_mkcert = check_command('mkcert')
        self.has_openssl = check_command('openssl')

    def welcome(self):
        """Display welcome message"""
        print(f"\n{Colors.BOLD}{Colors.BLUE}")
        print("╔═══════════════════════════════════════════════════════════╗")
        print("║                                                           ║")
        print("║        X/Twitter → xcancel Setup Wizard                   ║")
        print("║                                                           ║")
        print("║   This wizard will help you configure your redirect      ║")
        print("║   proxy to transparently forward X/Twitter traffic       ║")
        print("║   to xcancel.com                                          ║")
        print("║                                                           ║")
        print("╚═══════════════════════════════════════════════════════════╝")
        print(f"{Colors.END}\n")

        print_info("Detecting your environment...")
        print(f"  Docker: {'✓ Available' if self.has_docker else '✗ Not found'}")
        print(f"  mkcert: {'✓ Available' if self.has_mkcert else '✗ Not found'}")
        print(f"  OpenSSL: {'✓ Available' if self.has_openssl else '✗ Not found'}")

        if not self.has_docker:
            print_warning("Docker not found - you'll need to install it to run this setup")

        input(f"\n{Colors.BOLD}Press Enter to begin setup...{Colors.END}")

    def choose_web_server(self):
        """Ask which web server to use"""
        print_header("Web Server Selection")
        print("Choose your reverse proxy:")
        print(f"  • {Colors.BOLD}nginx{Colors.END}: Battle-tested, widely used")
        print(f"  • {Colors.BOLD}Caddy{Colors.END}: Simpler config (4 lines vs 27), modern\n")

        choice = ask_question(
            "Which web server do you want to use?",
            ["nginx", "Caddy"],
            default="Caddy"
        )
        self.config['web_server'] = choice.lower()
        print_success(f"Using {choice}")

    def choose_networking(self):
        """Ask about networking setup"""
        print_header("Network Configuration")
        print("Choose networking mode:")
        print(f"  • {Colors.BOLD}Bridge{Colors.END}: Simpler, uses host's IP with port forwarding")
        print(f"  • {Colors.BOLD}Macvlan{Colors.END}: Dedicated IP for container (better for Pi-hole/dnsmasq)\n")

        choice = ask_question(
            "Which networking mode?",
            ["Bridge (simple)", "Macvlan (dedicated IP)"],
            default="Bridge (simple)"
        )
        self.config['networking'] = 'bridge' if 'Bridge' in choice else 'macvlan'

        if self.config['networking'] == 'macvlan':
            self.configure_macvlan()
        else:
            self.configure_bridge()

    def configure_bridge(self):
        """Configure bridge networking"""
        print_info("Bridge mode will use your host's IP address")

        http_port = ask_text("HTTP port", default="80", validator=validate_port)
        https_port = ask_text("HTTPS port", default="443", validator=validate_port)

        self.config['http_port'] = http_port
        self.config['https_port'] = https_port

    def configure_macvlan(self):
        """Configure macvlan networking"""
        print_info("Macvlan mode gives the container a dedicated IP on your LAN")

        detected_if = detect_network_interface()
        detected_ip = detect_local_ip()

        if detected_if:
            print_info(f"Detected network interface: {detected_if}")
        if detected_ip:
            print_info(f"Detected your IP: {detected_ip}")
            # Infer subnet and gateway
            parts = detected_ip.split('.')
            subnet = f"{parts[0]}.{parts[1]}.{parts[2]}.0/24"
            gateway = f"{parts[0]}.{parts[1]}.{parts[2]}.1"
            print_info(f"Inferred subnet: {subnet}")
            print_info(f"Inferred gateway: {gateway}")

        interface = ask_text(
            "Network interface name",
            default=detected_if or "eth0"
        )

        subnet = ask_text(
            "LAN subnet (CIDR)",
            default=subnet if detected_ip else "192.168.1.0/24"
        )

        gateway = ask_text(
            "Gateway IP",
            default=gateway if detected_ip else "192.168.1.1",
            validator=validate_ip
        )

        # Suggest an available IP
        base_ip = subnet.split('/')[0].rsplit('.', 1)[0]
        server_name = 'caddy' if self.config['web_server'] == 'caddy' else 'nginx'
        suggested_ip = f"{base_ip}.100"

        server_ip = ask_text(
            f"{server_name.capitalize()} container IP",
            default=suggested_ip,
            validator=validate_ip
        )

        self.config['network_interface'] = interface
        self.config['lan_subnet'] = subnet
        self.config['lan_gateway'] = gateway
        self.config['server_ip'] = server_ip

    def choose_ssl(self):
        """Ask about SSL setup"""
        print_header("SSL Configuration")
        print("SSL certificates allow HTTPS interception without browser warnings")
        print(f"  • {Colors.BOLD}Skip{Colors.END}: HTTP-only redirect (simplest)")
        print(f"  • {Colors.BOLD}mkcert{Colors.END}: Automatic CA and cert generation (easiest)")
        print(f"  • {Colors.BOLD}Manual{Colors.END}: Full control with OpenSSL (advanced)\n")

        if not self.has_mkcert and not self.has_openssl:
            print_warning("Neither mkcert nor OpenSSL found")
            self.config['ssl'] = 'skip'
            return

        options = ["Skip SSL (HTTP only)"]
        if self.has_mkcert:
            options.append("mkcert (automatic)")
        if self.has_openssl:
            options.append("Manual OpenSSL")

        choice = ask_question("SSL setup:", options, default=options[1] if len(options) > 1 else options[0])

        if 'Skip' in choice:
            self.config['ssl'] = 'skip'
        elif 'mkcert' in choice:
            self.config['ssl'] = 'mkcert'
            if ask_yes_no("Generate certificates now?", default=True):
                self.generate_mkcert_certificates()
        else:
            self.config['ssl'] = 'manual'
            print_info("You'll need to follow docs/SSL_SETUP.md to create certificates manually")

    def generate_mkcert_certificates(self):
        """Generate certificates using mkcert"""
        print_info("Installing local CA...")
        try:
            subprocess.run(['mkcert', '-install'], check=True)
            print_success("CA installed")
        except subprocess.CalledProcessError:
            print_error("Failed to install CA")
            return

        print_info("Generating certificates for twitter.com, x.com, t.co...")
        try:
            result = subprocess.run(
                ['mkcert', 'twitter.com', 'x.com', '*.twitter.com', '*.x.com', 't.co', '*.t.co'],
                check=True,
                capture_output=True,
                text=True,
                cwd=self.project_dir
            )
            print_success("Certificates generated")

            # Find the generated files
            cert_file = None
            key_file = None
            for file in self.project_dir.glob('twitter.com+*.pem'):
                if '-key' in file.name:
                    key_file = file
                else:
                    cert_file = file

            if cert_file and key_file:
                # Copy to appropriate location
                ssl_dir = self.project_dir / self.config['web_server'] / 'ssl'
                ssl_dir.mkdir(parents=True, exist_ok=True)

                shutil.copy(cert_file, ssl_dir / 'twitter_bundle.pem')
                shutil.copy(key_file, ssl_dir / 'twitter_key.pem')

                os.chmod(ssl_dir / 'twitter_bundle.pem', 0o644)
                os.chmod(ssl_dir / 'twitter_key.pem', 0o600)

                print_success(f"Certificates copied to {ssl_dir}/")

                # Clean up original files
                cert_file.unlink()
                key_file.unlink()

        except subprocess.CalledProcessError as e:
            print_error(f"Failed to generate certificates: {e}")

    def choose_dns(self):
        """Ask about DNS setup"""
        print_header("DNS Configuration")
        print("You need to configure DNS to point twitter.com/x.com to your proxy")

        options = [
            "Pi-hole (recommended)",
            "UniFi/Ubiquiti",
            "pfSense/OPNsense",
            "Router built-in DNS",
            "Use included dnsmasq",
            "Manual (hosts file)"
        ]

        choice = ask_question("What DNS solution will you use?", options)

        if 'Pi-hole' in choice:
            self.config['dns'] = 'pihole'
            self.config['dns_instructions'] = 'docs/PIHOLE_SETUP.md'
        elif 'UniFi' in choice:
            self.config['dns'] = 'unifi'
            self.config['dns_instructions'] = 'docs/OTHER_DNS.md#unifi-ubiquiti'
        elif 'pfSense' in choice:
            self.config['dns'] = 'pfsense'
            self.config['dns_instructions'] = 'docs/OTHER_DNS.md#pfsense'
        elif 'dnsmasq' in choice:
            self.config['dns'] = 'dnsmasq'
            self.config['dns_instructions'] = 'docs/DNSMASQ_SETUP.md'
            self.config['include_dnsmasq'] = True
        elif 'Router' in choice:
            self.config['dns'] = 'router'
            self.config['dns_instructions'] = 'docs/OTHER_DNS.md'
        else:
            self.config['dns'] = 'manual'
            self.config['dns_instructions'] = 'docs/OTHER_DNS.md#per-device-configuration-without-dns-server'

    def generate_env_file(self):
        """Generate .env file"""
        print_header("Generating Configuration")

        env_file = self.project_dir / '.env'

        content = [
            "# X/Twitter → xcancel Configuration",
            f"# Generated by setup wizard",
            "",
            "# Timezone",
            f"TZ={os.environ.get('TZ', 'America/New_York')}",
            ""
        ]

        if self.config['networking'] == 'macvlan':
            content.extend([
                "# Macvlan Networking",
                f"NETWORK_INTERFACE={self.config['network_interface']}",
                f"LAN_SUBNET={self.config['lan_subnet']}",
                f"LAN_GATEWAY={self.config['lan_gateway']}",
                ""
            ])

            if self.config['web_server'] == 'nginx':
                content.append(f"NGINX_IP={self.config['server_ip']}")
            else:
                content.append(f"CADDY_IP={self.config['server_ip']}")

            if self.config.get('include_dnsmasq'):
                parts = self.config['server_ip'].rsplit('.', 1)
                dnsmasq_ip = f"{parts[0]}.{int(parts[1]) + 1}"
                content.extend([
                    f"DNSMASQ_IP={dnsmasq_ip}",
                    "UPSTREAM_DNS=1.1.1.1",
                ])
        else:
            content.extend([
                "# Bridge Networking",
                f"HTTP_PORT={self.config.get('http_port', '80')}",
                f"HTTPS_PORT={self.config.get('https_port', '443')}",
            ])

        with open(env_file, 'w') as f:
            f.write('\n'.join(content) + '\n')

        print_success(f"Created {env_file}")

        return env_file

    def show_next_steps(self):
        """Show next steps to user"""
        print_header("Setup Complete!")

        print(f"{Colors.BOLD}Configuration Summary:{Colors.END}")
        print(f"  Web Server: {self.config['web_server']}")
        print(f"  Networking: {self.config['networking']}")
        print(f"  SSL: {self.config['ssl']}")
        print(f"  DNS: {self.config['dns']}")

        print(f"\n{Colors.BOLD}Next Steps:{Colors.END}\n")

        print(f"1. {Colors.BOLD}Configure DNS{Colors.END}")
        print(f"   Point twitter.com, x.com, t.co to your proxy IP")
        print(f"   See: {self.config['dns_instructions']}")

        if self.config['ssl'] == 'manual':
            print(f"\n2. {Colors.BOLD}Generate SSL Certificates{Colors.END}")
            print(f"   See: docs/SSL_SETUP.md or docs/SSL_SETUP_MKCERT.md")

        step_num = 2 if self.config['ssl'] != 'manual' else 3

        print(f"\n{step_num}. {Colors.BOLD}Start the Service{Colors.END}")
        if self.config['web_server'] == 'nginx':
            cmd = "docker compose up -d"
        else:
            cmd = "docker compose -f docker-compose.caddy.yaml up -d"
        print(f"   {cmd}")

        step_num += 1
        print(f"\n{step_num}. {Colors.BOLD}Test the Setup{Colors.END}")
        print(f"   ./scripts/test-redirect.sh")
        print(f"   See: docs/TESTING.md")

        print(f"\n{Colors.GREEN}Configuration files have been generated!{Colors.END}")
        print(f"Your .env file is ready at: {self.project_dir}/.env\n")

        if self.has_docker and ask_yes_no("Start the service now?", default=False):
            self.start_service(cmd)

    def start_service(self, cmd: str):
        """Start the docker service"""
        print_info(f"Running: {cmd}")
        try:
            subprocess.run(cmd.split(), cwd=self.project_dir, check=True)
            print_success("Service started!")
            print_info("Check status: docker compose ps")
            print_info("View logs: docker compose logs -f")
        except subprocess.CalledProcessError as e:
            print_error(f"Failed to start service: {e}")

    def run(self):
        """Run the setup wizard"""
        try:
            self.welcome()
            self.choose_web_server()
            self.choose_networking()
            self.choose_ssl()
            self.choose_dns()
            self.generate_env_file()
            self.show_next_steps()
        except KeyboardInterrupt:
            print(f"\n\n{Colors.YELLOW}Setup cancelled{Colors.END}")
            sys.exit(1)
        except Exception as e:
            print_error(f"An error occurred: {e}")
            sys.exit(1)

def main():
    wizard = SetupWizard()
    wizard.run()

if __name__ == '__main__':
    main()
