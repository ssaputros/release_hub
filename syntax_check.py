import sys

with open('release.sh', 'r') as f:
    lines = f.readlines()

stack = []
for i, line in enumerate(lines):
    line_num = i + 1
    stripped = line.strip()
    if stripped.startswith('#') or not stripped:
        continue
    
    # Simple heuristic
    if stripped.startswith('if ') or '; then' in stripped and not stripped.startswith('elif '):
        if 'if ' in stripped:
            stack.append(('if', line_num))
    elif stripped.startswith('elif '):
        pass
    elif stripped.startswith('for ') or stripped.startswith('while '):
        stack.append(('loop', line_num))
    elif stripped.startswith('case '):
        stack.append(('case', line_num))
        
    if stripped.startswith('fi') or stripped.endswith('fi') or stripped == 'fi':
        if stack and stack[-1][0] == 'if':
            stack.pop()
        else:
            print(f"Unmatched fi at line {line_num}: {stripped} (stack: {stack})")
            
    if stripped.startswith('done') or stripped == 'done':
        if stack and stack[-1][0] == 'loop':
            stack.pop()
        else:
            print(f"Unmatched done at line {line_num}: {stripped} (stack: {stack})")
            
    if stripped.startswith('esac') or stripped == 'esac':
        if stack and stack[-1][0] == 'case':
            stack.pop()
            
if stack:
    print(f"Unclosed blocks: {stack}")
