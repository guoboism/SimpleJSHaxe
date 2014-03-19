SimpleJSHaxe
============

A port of a Simplified JavaScript Interpreter in AS3 by Sixsided to Haxe
see https://github.com/sixsided/Simplified-JavaScript-Interpreter

A piece of test code showing current progress:

	var ip:Interpreter = new Interpreter();
	var dict:Map<String, Dynamic> = new Map<String, Dynamic>();
	dict.set("MovieClip", MovieClip); //bind type
	dict.set("testAPI", testAPI);//bind function
	dict.set("gg", graphics); //bind object
	dict.set("stage", stage); //bind object
	dict.set("MouseEvent_CLICK", MouseEvent.CLICK); //bind object
	dict.set("onClick", onClick); //bind object
	ip.pushDict(dict);
	
	ip.doString("var m = 5 + 6 * 8;");
	ip.doString("var n = m + 1;");
	ip.doString("var a = 6;\rwhile(a<1000){a=a+1;}");
	ip.doString("function f(a){a=a+6;return a;}\rvar b = f(7);");
	ip.doString("var test = testAPI(5);");
	ip.doString("var mc = new MovieClip();");
	ip.doString("var s = 3; s = testAPI(s);");
	ip.doString("var s = 3; s = testAPI(s);");
	ip.doString("gg.drawCircle(200, 200, 200);");
	ip.doString("stage.addEventListener(MouseEvent_CLICK, onClick);");
	
	trace("findVar m:" + ip.vm.findVar("m"));
	trace("findVar n:" + ip.vm.findVar("n"));
	trace("findVar a:" + ip.vm.findVar("a"));
	trace("findVar b:" + ip.vm.findVar("b"));
	trace("findVar mc:" + ip.vm.findVar("mc"));
	trace("findVar s:" + ip.vm.findVar("s"));


