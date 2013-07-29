package ;

import flash.display.MovieClip;
import flash.display.Sprite;
import flash.display.StageAlign;
import flash.display.StageScaleMode;
import flash.events.Event;
import flash.display.Stage;
import flash.Lib;
import flash.text.TextField;
import flash.text.TextFormat;
import sjs.data.Token;

import sjs.util.ANSI;
import sjs.Lexer;
import sjs.Parser;
import sjs.Interpreter;

/**
 * ...
 * @author Guobo
 */

class Main extends Sprite 
{
	var inited:Bool;
	
	//public static function main() {
		
	//}

	public function new() 
	{
		
		stage.color = 0x996699;
		
		super();	
		addEventListener(Event.ADDED_TO_STAGE, added);
	}
	
	function resize(e) 
	{
		if (!inited) init();
		// else (resize or orientation change)
	}
	
	function init() 
	{
		if (inited) return;
		inited = true;

		// (your code here)
		
		var tf:TextField = new TextField();
		addChild(tf);
		var format = new TextFormat("Katamotz Ikasi", 30, 0x7A0026);
		tf.setTextFormat(format);
		tf.text = "Hello World";
		
		
		
		var ip:Interpreter = new Interpreter();
		
		var dict:Map<String, Dynamic> = new Map<String, Dynamic>();
		dict["MovieClip"] = MovieClip;
		dict["testAPI"] = testAPI;
		ip.pushDict(dict);
		
		var startTime;
		startTime = Lib.getTimer();
		
		/*
		for(i in 0...100000){
			ip.doString("var n = 7 + 2 * 15;");
		}
		
		trace((Lib.getTimer() - startTime));
		*/
		
		ip.doString("var m = 5 + 6 * 8;");
		ip.doString("var n = m + 1;");
		ip.doString("var a = 6;\rwhile(a<1000){a=a+1;}");
		ip.doString("function f(a){a=a+6;return a;}\rvar b = f(7);");
		ip.doString("var test = testAPI(5);");
		//ip.doString("gg.drawCircle(300, 300, 100);");
		
		trace("findVar m:" + ip.vm.findVar("m"));
		trace("findVar n:" + ip.vm.findVar("n"));
		trace("findVar a:" + ip.vm.findVar("a"));
		trace("findVar b:" + ip.vm.findVar("b"));
		
		// Stage:
		// stage.stageWidth x stage.stageHeight @ stage.dpiScale
		
		// Assets:
		// nme.Assets.getBitmapData("img/assetname.jpg");
	}

	/* SETUP */
	function added(e) 
	{
		removeEventListener(Event.ADDED_TO_STAGE, added);
		stage.addEventListener(Event.RESIZE, resize);
		#if ios
		haxe.Timer.delay(init, 100); // iOS 6
		#else
		init();
		#end
	}
	
	public function testAPI(a:Int):Int {
		return a * a;
	}
}
