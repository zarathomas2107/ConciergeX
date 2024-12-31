import requests

url = "https://content-service.tixuk.io/api/v3/products/id"

headers = {"accept": "application/json"}

response = requests.get(url, headers=headers)

print(response.text)