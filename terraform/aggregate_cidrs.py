import json
import sys
import requests
from netaddr import IPSet, cidr_merge

def get_github_cidrs():
    """
    Récupère toutes les plages d'adresses IPv4 pertinentes depuis l'API de GitHub.
    """
    try:
        # On contacte l'API publique et officielle de GitHub
        response = requests.get("https://api.github.com/meta", timeout=10 )
        response.raise_for_status()  # Lève une exception en cas d'erreur HTTP
        meta_data = response.json()
        
        # On combine les adresses de toutes les sections pour être exhaustif
        cidrs = meta_data.get("actions", []) + \
                meta_data.get("hooks", []) + \
                meta_data.get("web", []) + \
                meta_data.get("packages", []) + \
                meta_data.get("importers", [])
        
        # On filtre pour ne garder que les adresses IPv4 (celles sans ":")
        # et on utilise un "set" pour supprimer automatiquement les doublons.
        ipv4_cidrs = {c for c in cidrs if ":" not in c}
        return list(ipv4_cidrs)

    except requests.exceptions.RequestException as e:
        # En cas d'échec de la requête, on arrête le script avec une erreur
        print(f"Erreur lors de la récupération des métadonnées de GitHub: {e}", file=sys.stderr)
        sys.exit(1)

def aggregate_cidrs(cidrs):
    """
    Agrège une liste de plages CIDR en la plus petite liste possible.
    Exemple: ["1.1.1.0/25", "1.1.1.128/25"] devient ["1.1.1.0/24"]
    """
    if not cidrs:
        return []
    # La librairie netaddr fait tout le travail complexe de fusion des réseaux
    ip_set = IPSet(cidrs)
    merged_cidrs = cidr_merge(ip_set)
    return [str(cidr) for cidr in merged_cidrs]

def main():
    """
    Fonction principale qui orchestre la récupération, l'agrégation et l'impression
    du résultat au format attendu par Terraform.
    """
    initial_cidrs = get_github_cidrs()
    aggregated_cidrs = aggregate_cidrs(initial_cidrs)
    
    # --- LA MODIFICATION CLÉ ---
    # On transforme la liste finale en une seule chaîne de caractères,
    # avec les adresses séparées par une virgule.
    cidrs_as_string = ",".join(aggregated_cidrs)
    
    # On renvoie un objet JSON simple (un dictionnaire "plat")
    # que la source de données "external" de Terraform peut comprendre.
    output = {"aggregated_cidrs_string": cidrs_as_string}
    print(json.dumps(output))

if __name__ == "__main__":
    main()

