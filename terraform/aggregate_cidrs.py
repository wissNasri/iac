import json
import sys
import requests
from netaddr import IPSet, cidr_merge

def get_github_cidrs():
    """
    Récupère les plages d'adresses IPv4 de la section "actions" de l'API de GitHub.
    C'est la section la plus pertinente et la plus concise pour notre besoin.
    """
    try:
        # On contacte l'API publique et officielle de GitHub
        response = requests.get("https://api.github.com/meta", timeout=10 )
        response.raise_for_status()  # Lève une exception en cas d'erreur HTTP (ex: 404, 500)
        meta_data = response.json()
        
        # --- LA MODIFICATION CLÉ ---
        # Au lieu de combiner toutes les sections, nous ciblons uniquement
        # la section "actions", qui est la plus importante et la plus courte.
        cidrs = meta_data.get("actions", [])
        
        # On filtre la liste pour ne garder que les adresses IPv4 (celles sans ":")
        # et on utilise un "set" pour supprimer automatiquement les doublons potentiels.
        ipv4_cidrs = {c for c in cidrs if ":" not in c}
        
        return list(ipv4_cidrs)

    except requests.exceptions.RequestException as e:
        # En cas d'échec de la requête réseau, on arrête le script proprement
        # avec un message d'erreur clair pour le débogage.
        print(f"Erreur lors de la récupération des métadonnées de GitHub: {e}", file=sys.stderr)
        sys.exit(1)

def aggregate_cidrs(cidrs):
    """
    Agrège une liste de plages CIDR en la plus petite liste possible en fusionnant
    les réseaux contigus.
    Exemple: ["1.1.1.0/25", "1.1.1.128/25"] devient ["1.1.1.0/24"]
    """
    if not cidrs:
        return []
    
    # La librairie netaddr fait tout le travail complexe de fusion des réseaux.
    ip_set = IPSet(cidrs)
    merged_cidrs = cidr_merge(ip_set)
    
    return [str(cidr) for cidr in merged_cidrs]

def main():
    """
    Fonction principale qui orchestre la récupération, l'agrégation et l'impression
    du résultat au format attendu par la source de données "external" de Terraform.
    """
    # 1. Récupérer la liste des CIDR de la section "actions"
    initial_cidrs = get_github_cidrs()
    
    # 2. Agréger cette liste pour la rendre encore plus compacte
    aggregated_cidrs = aggregate_cidrs(initial_cidrs)
    
    # 3. Transformer la liste finale en une seule chaîne de caractères,
    #    avec les adresses séparées par une virgule.
    cidrs_as_string = ",".join(aggregated_cidrs)
    
    # 4. Créer un objet JSON simple (un dictionnaire "plat") avec une seule clé.
    #    C'est le format requis par `data "external"`.
    output = {"aggregated_cidrs_string": cidrs_as_string}
    
    # 5. Imprimer le JSON sur la sortie standard pour que Terraform puisse le lire.
    print(json.dumps(output))

if __name__ == "__main__":
    main()
