import curses
import sys
import os

def main(stdscr, items):
    if curses.has_colors():
        curses.use_default_colors()
        curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_WHITE)

    curses.curs_set(0) # Hide cursor
    stdscr.nodelay(False)
    
    selected_indices = set()
    current_row = 0
    search_query = ""
    
    # Pre-split and reverse projects so the latest ones are first
    menu_indices = []
    project_indices = []
    other_indices = []
    for i, item in enumerate(items):
        if item.startswith("[Menu]"):
            menu_indices.append(i)
        elif item.startswith("[Project]"):
            project_indices.append(i)
        else:
            other_indices.append(i)
    project_indices.reverse()
    
    while True:
        stdscr.clear()
        height, width = stdscr.getmaxyx()
        
        # Filter items
        filtered_menus = [i for i in menu_indices if search_query.lower() in items[i].lower()]
        filtered_projects = [i for i in project_indices if search_query.lower() in items[i].lower()]
        filtered_others = [i for i in other_indices if search_query.lower() in items[i].lower()]
                
        # Combine
        filtered_indices = filtered_menus + filtered_projects + filtered_others
        
        # Ensure current_row is valid
        if len(filtered_indices) == 0:
            current_row = 0
        elif current_row >= len(filtered_indices):
            current_row = len(filtered_indices) - 1
            
        # Draw search bar
        stdscr.addstr(0, 0, f"Search: {search_query}")
        stdscr.addstr(1, 0, "-" * (width - 1))
        
        # Draw items
        max_display = height - 3
        start_idx = max(0, current_row - max_display // 2)
        end_idx = min(len(filtered_indices), start_idx + max_display)
        
        for y, idx in enumerate(filtered_indices[start_idx:end_idx]):
            item = items[idx]
            display_item = item.replace("[Menu] ", "").replace("[Project] ", "")
            prefix = "[x]" if idx in selected_indices else "[ ]"
            display_text = f"{prefix} {display_item}"
            if len(display_text) > width - 1:
                display_text = display_text[:width - 1]
                
            if start_idx + y == current_row:
                stdscr.attron(curses.color_pair(1) if curses.has_colors() else curses.A_REVERSE)
                stdscr.addstr(y + 2, 0, display_text)
                stdscr.attroff(curses.color_pair(1) if curses.has_colors() else curses.A_REVERSE)
            else:
                stdscr.addstr(y + 2, 0, display_text)
                
        stdscr.refresh()
        
        try:
            key = stdscr.getch()
        except KeyboardInterrupt:
            sys.exit(1)
            
        if key == 27: # ESC
            stdscr.nodelay(True)
            if stdscr.getch() == -1: # True ESC
                sys.exit(1)
            stdscr.nodelay(False)
        elif key == curses.KEY_UP or key == 259: # Up arrow
            if current_row > 0:
                current_row -= 1
        elif key == curses.KEY_DOWN or key == 258: # Down arrow
            if current_row < len(filtered_indices) - 1:
                current_row += 1
        elif key == ord(' '): # Space
            if filtered_indices:
                idx = filtered_indices[current_row]
                if idx in selected_indices:
                    selected_indices.remove(idx)
                else:
                    selected_indices.add(idx)
        elif key == 10 or key == 13: # Enter
            break
        elif key == curses.KEY_BACKSPACE or key == 127 or key == 8: # Backspace
            search_query = search_query[:-1]
        elif key >= 32 and key <= 126: # Printable chars
            search_query += chr(key)
            
    return [items[i] for i in sorted(selected_indices)]

if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(1)
        
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    with open(input_file, 'r') as f:
        items = [line.strip() for line in f if line.strip()]
        
    if not items:
        sys.exit(0)
        
    try:
        selected = curses.wrapper(main, items)
        with open(output_file, 'w') as f:
            for s in selected:
                f.write(s + "\n")
    except Exception as e:
        sys.exit(1)
