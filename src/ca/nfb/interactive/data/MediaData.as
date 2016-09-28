package ca.nfb.interactive.data {
	import flash.display.Sprite;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;

	public class MediaData {
		public static const TYPE_FULL_VID:int = 1;
		public static const TYPE_SEGMENTED_VID:int = 2;
		public static const TYPE_MASKED_VID:int = 3;
		
		public var playType:int = TYPE_FULL_VID;
		public var videoName:String = Strings.VIDEO_MENU;
		public var loadType:String = Strings.LOAD_PROGRESSIVE;
		public var netConnection:NetConnection;
		public var netStream:NetStream;
		public var onNetStatus:Function;
		
		public var currentTime:Number = 0;
		public var playing:Boolean = false;
		public var loaded:Boolean = false;
		
		public var width:Number = 0;
		public var height:Number = 0;
		
		public var baseStreamUrl:String; // Base URL for stream.
		public var crossdomainUrl:String;
		public var url:String; // Video URL.
		public var segments:Vector.<MediaSegment>; // Array of segments in case not using one url.
		public var currentSegment:MediaSegment; // Currently playing segment.
		public var fallbackUrl:String; // Video fallback URL.
		public var useFallback:Boolean = false;
		public var extraData:XML;
		
		public var video:Video;
		public var videoContainer:Sprite;
		
		public var alpha:Number = 1;
		
		public function MediaData() { }
		
		/** Returns segment with matching name, or null if none exist. */
		public function getSegmentByName(name:String):MediaSegment {
			if (!segments) { return null; }
			for (var i:int = segments.length - 1; i >= 0; i--) {
				if (segments[i].name == name) {
					return segments[i];
				}
			}
			return null;
		}
		
		/** Returns the segment with the highest start time without going over time. */
		public function getSegmentByTime(time:Number):MediaSegment {
			if (!segments) { return null; }
			for (var i:int = segments.length - 1; i >= 0; i--) {
				if (segments[i].start <= time) {
					return segments[i];
				}
			}
			return null;
		}
	}
}