import copy

def clean_params_for_logging(params):
    """Remove embeddings from params for cleaner logging"""
    if not params:
        return params
    clean_params = copy.deepcopy(params)
    if 'search_embedding' in clean_params:
        clean_params['search_embedding'] = '[hidden]'
    return clean_params 