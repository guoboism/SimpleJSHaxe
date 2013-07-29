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
	
	public var first:Dynamic;
	public var second:Dynamic;
	public var third:Dynamic;
	
	public var isFunctionCall:Bool;
	public var scope:Array<String>;
	public var isStatement:Bool;
	public var expectFunctionCall:Void->Void;
	public var assignment:Bool;
	
	public var isAnonymous:Bool;
	
	public function new(?led_:Dynamic->Dynamic,?nud_:Void->Dynamic,?std_:Void->Dynamic,?bpow_:Int = 0) 
	{
		super();
		
		isPrefix = false;
		led = led_;
		nud = nud_;
		std = std_;
		bpow = bpow_;
		
		isAnonymous = false;
		
		toString = defaultToString;
		
		//{nud, led, std, bpow, codegen } associated with an id
	}
	
	public function extendFromSymbol(s:Symbol):Void {
		if (s == null) return; 
		

		
		//id = s.id; 
		led = s.led;
		nud = s.nud;
		std = s.std;
		toString = s.toString;
		bpow = s.bpow;
		codegen = s.codegen;
		isPrefix = s.isPrefix;
		first = s.first;
		second = s.second;
		third = s.third;
		isFunctionCall = s.isFunctionCall;
		scope = s.scope;
		isStatement = s.isStatement;
		expectFunctionCall = s.expectFunctionCall;
		assignment = s.assignment;
		isAnonymous = s.isAnonymous;
	}
	
	public function extendFromToken(t:Token):Void {
		if (t == null) return;
		
		value = t.value;
		type = t.type;
		from = t.from;
		to = t.to;
	}
	
	public function defaultToString():String {
		return "Symbol: id " + id + " value " + value;
		
	}
	
}