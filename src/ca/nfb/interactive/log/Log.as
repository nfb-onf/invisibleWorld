package ca.nfb.interactive.log {
	import flash.external.ExternalInterface;

	public class Log {
		public static const USE_LOG:Boolean = false;
		
		protected static var lastTime:uint = 0;
		
		public static function logmsg(message:String):void {
			//return; // ALEX: No logging for the build.
			
			trace (message);
			if (ExternalInterface.available) {
				ExternalInterface.call('console.log', message);
			}
		}
		
		public static function logtime(message:String):void {
			return; // ALEX: No logging for the build.
			
			var time:uint = new Date().time;
			trace(message + " - " + (time - lastTime) + "ms");
			lastTime = time;
		}
	}
}