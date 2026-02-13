import yaml
import os

config_path = os.path.expanduser("~/.kube/config-tekton")
with open(config_path) as f:
    config = yaml.safe_load(f)

for cluster in config['clusters']:
    if 'certificate-authority-data' in cluster['cluster']:
        del cluster['cluster']['certificate-authority-data']
    cluster['cluster']['insecure-skip-tls-verify'] = True

with open(config_path, 'w') as f:
    yaml.dump(config, f)
    
print("Updated kubeconfig to skip TLS verify")