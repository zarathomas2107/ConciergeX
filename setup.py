from setuptools import setup, find_packages

setup(
    name="search_service",
    version="0.1",
    packages=find_packages(),
    install_requires=[
        'openai',
        'python-dotenv',
        'supabase',
        'pytest',
        'pytest-asyncio'
    ],
) 