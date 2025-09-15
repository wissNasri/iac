import json
import sys
import requests
from netaddr import IPSet, cidr_merge

def get_github_cidrs():
    """Fetches all relevant IPv4 CIDR blocks from GitHub meta API."""
    try:
        response = requests.get("https://api.github.com/meta", timeout=10 )
        response.raise_for_status()
        meta_data = response.json()
        # On prend toutes les sections pertinentes
        cidrs = meta_data.get("actions", []) + \
                meta_data.get("hooks", []) + \
                meta_data.get("web", []) + \
                meta_data.get("packages", [])
        
        # On filtre pour ne garder que l'IPv4 et on dédoublonne
        ipv4_cidrs = {c for c in cidrs if ":" not in c}
        return list(ipv4_cidrs)
    except requests.exceptions.RequestException as e:
        print(f"Error fetching GitHub meta data: {e}", file=sys.stderr)
        sys.exit(1)

def aggregate_cidrs(cidrs):
    """Aggregates a list of CIDR blocks into the smallest possible list."""
    if not cidrs:
        return []
    ip_set = IPSet(cidrs)
    merged_cidrs = cidr_merge(ip_set)
    return [str(cidr) for cidr in merged_cidrs]

def main():
    """Main function to fetch, aggregate, and print CIDRs as JSON."""
    initial_cidrs = get_github_cidrs()
    aggregated_cidrs = aggregate_cidrs(initial_cidrs)
    
    # Terraform attend une sortie JSON sur la sortie standard
    output = {"aggregated_cidrs": aggregated_cidrs}
    print(json.dumps(output))

if __name__ == "__main__":
    main()
