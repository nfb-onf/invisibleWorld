package ca.nfb.interactive.data {
	import flash.events.EventDispatcher;

	public class Strings extends EventDispatcher {
		public static const LANG_EN:String = "en"; // English
		public static const LANG_FR:String = "fr"; // Khmer
		public static const LANG_KH:String = "kh"; // Khmer
		
		public static const LOAD_PROGRESSIVE:String = "progressive";
		public static const LOAD_STREAMING:String = "stream";
		
		public static const VIDEO_MENU:String = "menu";
		public static const VIDEO_MAIN:String = "main";
		public static const VIDEO_FAST:String = "fast";
		public static const VIDEO_SLOW:String = "slow";
		public static const AUDIO_INTRO_LOOP:String = "introloop";
		
		public static const WEB_BACKUP:String = "_web";
		
		public static var baseUrl:String = "";
		public static var lang:String = "";
		public static var load:String = "";
		public static var aboutTextEn:String = "";
		public static var aboutTextFr:String = "";
		public static var aboutTextKh:String = "";
		public static var aboutImages:XMLList;
		
		protected static var _media:Object;

		public static function getFont(bold:Boolean):String {
			switch (lang) {
				case LANG_EN:
					return "helvetica" + (bold ? "_bold" : "");
					break;
				case LANG_FR:
					return "helvetica" + (bold ? "_bold" : "");
					break;
				case LANG_KH:
					return "khmer" + (bold ? "_bold" : "");
					break;
				default:
					return "helvetica";
					break;
			}
		}
		public static function set mediaData(obj:Object):void {
			_media = obj;
		}
		
		public static function getMediaData(id:String):MediaData {
			return _media[id];
		}
	}
}