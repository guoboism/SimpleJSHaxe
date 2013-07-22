package sjs.data;

/**
 * ...
 * @author Guobo
 */
class Symbol
{

	
	
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
	
	public function new(?led_:Dynamic->Dynamic,?nud_:Void->Dynamic,?std_:Void->Dynamic,?bpow_:Int) 
	{
		
		
		isPrefix = false;
		
		//{nud, led, std, bpow, codegen } associated with an id
		
		
	}
	
}