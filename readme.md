# Julia Binary Metaheuristics 2

This time I tried to stack modules on top of each other like this:

```
-----------
| Problem |
-----------
	|
	V
-----------
| Solution |
------------
	|
	V
------------
| Watershed |
-------------
	|
	V
------------	------------
| DescFunc |	| Perturb |
------------	-----------
	|	_____________|
	V	V			
---------	-----------			
| PMeta |   | Execute |
---------	-----------
	|  __________|
	V  V
--------------
| Experiment |
--------------
	|
	V
------
| MH |
------

```

I like this method because I can combine it with the Juno IDE's integrated
REPL and develop from the top down. It does lead to an overly complex
structure.  
