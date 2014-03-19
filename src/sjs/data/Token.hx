package sjs.data;

/**
 * ...
 * @author Guobo
 */

enum TokenType {
	TName;
	TOperator;
	TNumber;
	TString;
}
 
class Token
{
	public var type:TokenType;
	public var value:Dynamic;//?
	public var from:Int;
	public var to:Int;
	
	public function new(?type_:TokenType, ?value_:Dynamic, ?from_:Int, ?to_:Int) 
	{
		type = type_;
		value = value_;
		from = from_;
		to = to_;
	}
	
	public function error(msg:String):Void { throw(msg); }
	
}