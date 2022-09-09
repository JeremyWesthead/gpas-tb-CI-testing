import json
from recursive_diff import recursive_eq


def concatFields(d: dict) -> str:
    '''Concat the value of a dictionary in the order of the sorted keys
    Args:
        d (dict): Dictionary input
    Returns:
        str: String of values
    '''
    return ''.join([str(d[key]) for key in sorted(list(d.keys()))])

def sortValues(json: dict) -> dict:
    '''Sort the values within the VARIANTS, MUTATIONS and EFFECTS lists in a JSON.
    THis allows to test for contents equality as order is not particularly important here
    Args:
        json (dict): JSON in
    Returns:
        dict: JSON with VARIANTS, MUTATIONS and EFFECTS lists in reproducable orders for equality checks
    '''
    variants = json['data']['VARIANTS']
    mutations = json['data'].get('MUTATIONS', None)
    effects = json['data'].get('EFFECTS', None)
    
    json['data']['VARIANTS'] = sorted(variants, key=concatFields)
    if mutations is not None:
        json['data']['MUTATIONS'] = sorted(mutations, key=concatFields)
    if effects is not None:
        for drug in effects.keys():
            json['data']['EFFECTS'][drug] = sorted(effects[drug], key=concatFields)
    
    return json


def checkJSONEq(suffix: str) -> None:
    '''Read the expected and actual JSONs of a given suffix, then compare them (ignoring timestamp)

    Args:
        suffix (str): Suffix of the test. One of MDR, preXDR, XDR and WHO
    '''
    expected = sortValues(json.load(open(f"expected/syn-illumina-{suffix}/syn-illumina-{suffix}.gnomon-out.json")))
    actual = sortValues(json.load(open(f"syn-illumina-{suffix}/syn-illumina-{suffix}/syn-illumina-{suffix}.gnomon-out.json")))

    #Remove datetime as this is unreplicable
    del expected['meta']['UTC-datetime-run']
    del actual['meta']['UTC-datetime-run']

    recursive_eq(expected, actual)


def test_MDR():
    checkJSONEq("MDR")

def test_preXDR():
    checkJSONEq("preXDR")

def test_XDR():
    checkJSONEq("XDR")

def test_WHO():
    checkJSONEq("WHO")



