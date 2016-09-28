package ca.nfb.interactive.utils {
	public class FileUtil {
		
		private static var baseUrl:String = "";
		
		public static function setBase(url:String):void {
			baseUrl = url;
		}
		
		public static function getFileUrl(url:String):String {
			if (!url) { 
				return ""; 
			} else if (url.indexOf("http://") >= 0) {
				return url;
			} else if (url.indexOf("rtmp://") >= 0) {
				return url;
			//} else if (File) {
			//	return File.applicationDirectory.resolvePath(url).url;
			} else {
				return baseUrl + url;
			}
		}
	}
}