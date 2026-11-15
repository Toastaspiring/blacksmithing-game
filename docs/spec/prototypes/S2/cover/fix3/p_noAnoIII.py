import sys, subprocess
subprocess.check_call([sys.executable, "p_noIII.py", sys.argv[1]])
subprocess.check_call([sys.executable, "p_noA.py", sys.argv[1]])
