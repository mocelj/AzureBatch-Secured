import argparse
import logging

from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

def testKvConnection(kv_url,secretName, secretValue,local_console=False):
    # Get the credential (SP, MI, ...)
    kvcredential = DefaultAzureCredential()
    try:
        
        kvclient = SecretClient(vault_url=kv_url, credential=kvcredential)

        # Test 1

        kvclient.set_secret(secretName,secretValue)
        testSecretValue = kvclient.get_secret(secretName)
        
        logging.debug("Test 1: Set and retrive a test secret in the Key Vault.")
        logging.debug("Secret Name: {name} , Secret Value: {secret}".format(name=testSecretValue.name, secret=testSecretValue.value))

        if local_console:
            print("Test 1: Set and retrive a test secret in the Key Vault.")
            print("Secret Name: {name} , Secret Value: {secret}".format(name=testSecretValue.name, secret=testSecretValue.value))

        # Test 2

        # list secrets
        secrets = kvclient.list_properties_of_secrets()
    
        logging.debug("Test 2: List all secret Names found in the Key Vault.")
        logging.debug("-----------------------------------------------------")

        if local_console:
            print("Test 2: List all secret Names found in the Key Vault.")
            print("-----------------------------------------------------")
        
        for secret in secrets:
            logging.debug("Secret Id: {id} , Secret Name: {name}".format(name=secret.name, id=secret.id))
            if local_console:
                 print("Secret Id: {id} , Secret Name: {name}".format(name=secret.name, id=secret.id))

    except: 
         logging.error("Could not establish a connection to Key Vault URI {uri}. Verify the Key Vault name.".format(uri=kv_url))

if __name__ == '__main__':
    
    # initiate the parser
    parser = argparse.ArgumentParser()
    # add a long and a short argument
    parser.add_argument("-k", "--keyVault", help="Specifiy the Azure Key Vault which holds the secrets.")
    parser.add_argument("-s", "--secret",   help="Name of the test kv secret.")
    parser.add_argument("-v", "--value",    help="Secret Value of the test kv secret.")

       
    # read arguments from the command line
    args = parser.parse_args()

    # Default Values
    kvURI_base = 'https://&KEYVAULTNAME&.vault.azure.net/'
    kv_name = 'kv-fsistream-modr'
    secretName = 'test-secret'
    secretValue = 'az-batch'
       
    if args.keyVault:
        kv_name = args.keyVault

    if args.secret: 
        secretName = args.secret

    if args.value:
        secretValue = args.value
    
    # Test the connection to the Azure Key Vault
    testKvConnection(kvURI_base.replace('&KEYVAULTNAME&',kv_name), secretName, secretValue,local_console=True)
    
