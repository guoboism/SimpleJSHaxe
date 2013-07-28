package sjs.data;

/**
 * ...
 * @author Guobo
 */
class Symbol extends Token
{

	
	public var id:String;
	
	public var led:Dynamic->Dynamic;
	public var nud:Void->Dynamic;
	public var std:Void->Dynamic;
	
	public var toString:Void->String;
	public var bpow:Int;
	public var codegen:Dynamic;
	
	public var isPrefix:Bool;
	public var fisrt:Dynamic;
	public var second:Dynamic;
	public var isFunctionCall:Bool;
	public var scope:Array<String>;
	public var isStatement:Bool;
	public var expectFunctionCall:Void->Void;
	
	public function new(?led_:Dynamic->Dynamic,?nud_:Void->Dynamic,?std_:Void->Dynamic,?bpow_:Int) 
	{
		super();
		
		isPrefix = false;
		led = led_;
		nud = nud_;
		std = std_;
		bpow = bpow_;
		
		
		
		
		
		//{nud, led, std, bpow, codegen } associated with an id
	}
	
	public function extendFromSymbol(s:Symbol):Void {
		id = s.id; 
		led = s.led;
		nud = s.nud;
		std = s.std;
		toString = s.toString;
		bpow = s.bpow;
		codegen = s.codegen;
		isPrefix = s.isPrefix;
		fisrt = s.fisrt;
		second = s.second;
		isFunctionCall = s.isFunctionCall;
		scope = s.scope;
		isStatement = s.isStatement;
		expectFunctionCall = s.expectFunctionCall;
		
	}
	
	public function extendFromToken(t:Token):Void {
		value = t.value;
		type = t.type;
		from = t.from;
		to = t.to;
	}
	
}