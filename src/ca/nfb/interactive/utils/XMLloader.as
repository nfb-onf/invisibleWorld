package ca.nfb.interactive.utils {
	import flash.display.LoaderInfo;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	
	import ca.nfb.interactive.log.Log;
	
	public class XMLloader {
		private static var loader:URLLoader = new URLLoader();
		
		public static function loadXML(xmlURL:String, func:Function):void {
			loader.addEventListener(Event.COMPLETE, onXMLLoaded);
			loader.addEventListener(IOErrorEvent.IO_ERROR, onXMLError);
			loader.load(new URLRequest(xmlURL));
			
			function onXMLLoaded(e:Event):void {
				Log.USE_LOG && Log.logmsg("Loaded Config");
				loader.removeEventListener(Event.COMPLETE, onXMLLoaded);
				var xml:XML = new XML(e.target.data);
				func(xml);
			}
			
			function onXMLError(e:IOErrorEvent):void {	
				Log.USE_LOG && Log.logmsg(e.type + ": " + e.text);
				Log.USE_LOG && Log.logmsg((e.target as LoaderInfo).url);
			}
		}
		
	}
}