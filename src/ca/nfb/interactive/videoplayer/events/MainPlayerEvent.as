package ca.nfb.interactive.videoplayer.events {
	import flash.events.Event;
	
	public class MainPlayerEvent extends Event {
		
		public static const CHANGE_LANGUAGE:String = "changeLanguage";
		public static const DOWNLOAD_APP:String = "downloadApp";
		public static const LOAD_COMPLETED:String = "loadCompleted";
		public static const LOAD_FAILED:String = "loadFailed";
		public static const LOAD_SUCCEEDED:String = "loadSucceeded";
		public static const READY_TO_RECEIVE_MEDIA:String = "readyToReceiveMedia";
		public static const TRACK_ANALYTICS:String = "trackAnalytics";
		
		public var data:Object;
		
		public function MainPlayerEvent(type:String, data:Object = null) {
			super(type, bubbles, cancelable);
			this.data = data;
		}
	}
}