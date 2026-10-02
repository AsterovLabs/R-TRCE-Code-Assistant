"""
samples/07_python_student_traps.py -- Python Pitfall Sentinel Showcase
Deliberate collection of beginner programming pitfalls in Python.
Used to verify the automated detector and provide student remediation advice.
"""

# Trap 1: Mutable Default Argument (retains state across function calls)
def append_to_cache(item, cache=[]):
    cache.append(item)
    return cache

# Trap 2: Direct Equality with None (should use identity 'is None')
def check_status(response_code):
    if response_code == None:
        return "Unknown"
    return "Received"

# Trap 3: Redundant Boolean comparison
def is_ready(flag):
    if flag == True:
        return "System Ready"
    return "Waiting"

# Trap 4: Shadowing Python standard built-in functions
def format_numbers(values):
    list = [x * 2 for x in values]
    return list

# Trap 5: Bare 'except:' clause (masks KeyboardInterrupt and SystemExit)
def risky_calculation(val):
    try:
        result = 100 / val
    except:
        result = 0
    return result

# Trap 6: Modifying list while iterating over it
def remove_negatives(numbers):
    for num in numbers:
        if num < 0:
            numbers.remove(num)
    return numbers

# Trap 7: Off-by-one indexing error (0-indexing confusion vs 1-indexing)
def get_final_element(items):
    last = items[len(items)]
    return last
