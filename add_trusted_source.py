import os
import requests
import json

def get_public_ip():
    """Retrieve the public IP address of the machine."""
    try:
        response = requests.get('https://api.ipify.org?format=json')
        response.raise_for_status()
        ip = response.json().get('ip')
        return ip
    except requests.RequestException as e:
        print(f"Error retrieving public IP: {e}")
        return None

def list_databases(api_token):
    """List all database clusters in the account."""
    url = 'https://api.digitalocean.com/v2/databases'
    headers = {
        'Authorization': f'Bearer {api_token}',
        'Content-Type': 'application/json',
    }
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        return response.json().get('databases', [])
    except requests.RequestException as e:
        print(f"Error listing databases: {e}")
        return []

def find_database(databases, identifier):
    """
    Find a database cluster by name or hostname.
    `identifier` can be the cluster name or the cluster hostname.
    """
    for db in databases:
        if db['name'] == identifier or db['uri'].startswith(identifier):
            return db
    return None

def add_trusted_source(api_token, db_id, ip_address):
    """Add a trusted source IP to the specified database cluster."""
    url = f'https://api.digitalocean.com/v2/databases/{db_id}/trusted_sources'
    headers = {
        'Authorization': f'Bearer {api_token}',
        'Content-Type': 'application/json',
    }
    data = {
        'type': 'ip',
        'value': ip_address
    }
    try:
        response = requests.post(url, headers=headers, json=data)
        if response.status_code == 201:
            print(f"SUCCESS: Added {ip_address} to trusted sources.")
        elif response.status_code == 409:
            print(f"INFO: {ip_address} is already a trusted source.")
        else:
            print(f"FAILED: Could not add trusted source. Status Code: {response.status_code}")
            print(f"Response: {response.text}")
    except requests.RequestException as e:
        print(f"Error adding trusted source: {e}")

def main():
    # Retrieve the API token from environment variable
    api_token = os.getenv('DIGITALOCEAN_API_TOKEN')
    if not api_token:
        print("Error: DIGITALOCEAN_API_TOKEN environment variable is not set.")
        return

    # Retrieve your public IP
    ip_address = get_public_ip()
    if not ip_address:
        print("Error: Unable to retrieve public IP.")
        return
    print(f"Your Public IP: {ip_address}")

    # List all database clusters
    databases = list_databases(api_token)
    if not databases:
        print("No databases found or error retrieving databases.")
        return

    # Define your database cluster identifier (name or hostname)
    # Replace this with your actual cluster name or hostname
    cluster_identifier = 'private-db-mongodb-nyc3-54764-54a30691.mongo.ondigitalocean.com'

    # Find the specific database cluster
    database = find_database(databases, cluster_identifier)
    if not database:
        print(f"Database cluster '{cluster_identifier}' not found.")
        return

    db_id = database['id']
    print(f"Found Database Cluster: {database['name']} (ID: {db_id})")

    # Add your IP to trusted sources
    add_trusted_source(api_token, db_id, ip_address)

if __name__ == "__main__":
    main()
