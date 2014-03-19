package sjs.util;

	/**
	 * ...
	 * @author Guobo
	 */
	class ANSI {

    public static var  START:String = "\\u001B[";
    public static var  BLACK_TEXT :String = "\\u001B[0;30m";
    public static var  RED_TEXT :String = "\\u001B[0;31m";
    public static var  GREEN_TEXT :String = "\\u001B[0;32m";
    public static var  YELLOW_TEXT :String = "\\u001B[0;33m";
    public static var  BLUE_TEXT :String = "\\u001B[0;34m";
    public static var  MAGENTA_TEXT :String = "\\u001B[0;35m";
    public static var  CYAN_TEXT :String = "\\u001B[0;36m";
    public static var  WHITE_TEXT :String = "\\u001B[0;37m";
    public static var  DEFAULT_TEXT :String = "\\u001B[0;39m";

    public static var  BLACK_BG :String = "\\u001B[0;40m";
    public static var  RED_BG :String = "\\u001B[0;41m";
    public static var  GREEN_BG :String = "\\u001B[0;42m";
    public static var  YELLOW_BG :String = "\\u001B[0;43m";
    public static var  BLUE_BG :String = "\\u001B[0;44m";
    public static var  MAGENTA_BG :String = "\\u001B[0;45m";
    public static var  CYAN_BG :String = "\\u001B[0;46m";
    public static var  WHITE_BG :String = "\\u001B[0;47m";
    public static var  DEFAULT_BG :String = "\\u001B[0;49m";
    public static var  ALTERNATE_BUFFER:String =  "\\u001B[?1049h";
    public static var  MAIN_BUFFER:String =  "\\u001B[?1049l";
    public static var  INVERT_BACKGROUND:String =  "\\u001B[7m";
    public static var  NORMAL_BACKGROUND:String =  "\\u001B[27m";
    public static var  RESET :String = "\\u001B[0;0m";
    public static var  BOLD:String =  "\\u001B[0;1m";
    public static var  BOLD_OFF:String = "\\u001B[0;22m";
    public static var  UNDERLINE:String =  "\\u001B[0;4m";
    public static var  UNDERLINE_OFF:String =  "\\u001B[0;24m";
    public static var  BLINK :String = "\\u001B[0;5m";
    public static var  BLINK_OFF :String = "\\u001B[0;25m";
    public static var  CURSOR_START :String = "\\u001B[1G";
    public static var  CURSOR_ROW :String = "\\u001B[6n";
    public static var  CLEAR_SCREEN :String = "\\u001B[2J";
    public static var  CURSOR_SAVE :String = "\\u001B[s";
    public static var  CURSOR_RESTORE :String = "\\u001B[u";


    private static function   getStart():String {
        return START;
    }

    private static function   blackText():String {
        return BLACK_TEXT;
    }

    private static function   redText():String {
        return RED_TEXT;
    }

    private static function   greenText():String {
        return GREEN_TEXT;
    }

    private static function   yellowText():String {
        return YELLOW_TEXT;
    }

    private static function   blueText():String {
        return BLUE_TEXT;
    }

    private static function   magentaText():String {
        return MAGENTA_TEXT;
    }

    private static function    cyanText():String {
        return CYAN_TEXT;
    }

    private static function   whiteText():String {
        return WHITE_TEXT;
    }

    private static function   defaultText():String {
        return DEFAULT_TEXT;
    }

    private static function   blackBackground():String {
        return BLACK_BG;
    }

    private static function   redBackground():String {
        return RED_BG;
    }

    private static function   greenBackground():String {
        return GREEN_BG;
    }

    private static function   yellowBackground():String {
        return YELLOW_BG;
    }

    private static function   blueBackground():String {
        return BLUE_BG;
    }

    private static function   magentaBackground():String {
        return MAGENTA_BG;
    }

    private static function   cyanBackground():String {
        return CYAN_BG;
    }

    private static function   whiteBackground():String {
        return WHITE_BG;
    }

    private static function   defaultBackground():String {
        return DEFAULT_BG;
    }

    private static function   reset():String {
        return RESET;
    }

    private static function   getAlternateBufferScreen():String {
       return ALTERNATE_BUFFER;
    }

    private static function   getMainBufferScreen():String {
        return MAIN_BUFFER;
    }

    private static function   getInvertedBackground():String {
        return INVERT_BACKGROUND;
    }

    private static function   getNormalBackground():String {
        return NORMAL_BACKGROUND;
    }

    private static function   getBold():String {
        return BOLD;
    }

    private static function   getBoldOff():String {
        return BOLD_OFF;
    }

    private static function   getUnderline():String {
        return UNDERLINE;
    }

    private static function   getUnderlineOff():String {
        return UNDERLINE_OFF;
    }

    private static function   getBlink():String {
        return BLINK;
    }

    private static function   getBlinkOff():String {
        return BLINK_OFF;
    }

    private static function   moveCursorToBeginningOfLine():String {
        return CURSOR_START;
    }

    private static function   getCurrentCursorPos():String {
       return CURSOR_ROW;
    }

    private static function   clearScreen():String {
        return CLEAR_SCREEN;
    }

    private static function   saveCursor():String {
        return CURSOR_SAVE;
    }

    private static function   restoreCursor():String {
        return CURSOR_RESTORE;
    }
}

