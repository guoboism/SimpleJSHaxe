package ;

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
		
		
		/*
		var startTime;
		startTime = Lib.getTimer();
		
		for(i in 0...1000000){
			var res:Array<Token> = Lexer.tokenize("var s = 0; s = s + 100;");
		}
		trace((Lib.getTimer() - startTime) / 1000);
		
		//0.873
		*/
		
		var ip:Interpreter = new Interpreter();
		ip.doString("var m = 5 + 8;");
		trace("findVar m:" + ip.vm.findVar("m"));
		
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
	
	
}
