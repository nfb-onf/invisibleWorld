package ca.nfb.interactive.display {
	import com.gskinner.motion.GTween;
	
	import flash.display.MovieClip;
	import flash.display.Stage;
	import flash.events.AsyncErrorEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.media.SoundTransform;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.system.Security;
	
	import ca.nfb.interactive.data.MediaData;
	import ca.nfb.interactive.data.MediaSegment;
	import ca.nfb.interactive.data.Strings;
	import ca.nfb.interactive.display.events.VideoPlayerEvent;
	import ca.nfb.interactive.log.Log;
	import ca.nfb.interactive.utils.TweenUtil;

	public class AbstractVideoPlayer extends MovieClip {
		protected static var USE_FULL_LOAD:Boolean = false;
		
		protected var myStage:Stage;
		
		// Width and height of the playback screen. Should be constrained to stage. Doesn't change.
		protected var screenW:Number = 960;
		protected var screenH:Number = 540;
		
		// Width and height of the stage, not counting nav bars.
		protected var stageW:Number = 0;
		protected var stageH:Number = 0;
		
		// Intended width and height of currently active vid, supplied by parameters.
		protected var vidW:Number = 0;
		protected var vidH:Number = 0;
		
		protected var vidHash:Object = {};
		protected var vidOrder:Vector.<String> = new Vector.<String>();
		protected var lastMedia:MediaData;
		protected var loadingMedia:MediaData;
		protected var loadingQueue:Vector.<MediaData>;
		protected var currentMedia:MediaData;
		protected var volumeControl:SoundTransform;
		protected var nsLoading:Boolean = false;
		protected var nsSeeking:Boolean = false;
		protected var nsBuffering:Boolean = false;
		protected var nsStopped:Boolean = false;
		protected var nsSeekTarget:Number = -1;
		
		protected var leftMaskX:Number = 200;
		protected var rightMaskX:Number = 400;
		protected var halfMaskGapFrac:Number = 1 / 9.6;

		protected var progressPercent:Number = 0;
		
		protected var streamDuration:Number = 0;
		protected var videoFading:MediaData;
		protected var videoFadeTween:GTween;
		protected var videoFadeTarget:Number = 0;
		
		protected var prevBandwidthTime:Number = 0;
		protected var prevBandwidthBytesLoaded:Number = 0;
		
		public function AbstractVideoPlayer(stage:Stage, wid:Number, hei:Number) {
			myStage = stage;
			stageW = wid;
			stageH = hei;
			
			volumeControl = new SoundTransform();
			
			loadingQueue = new Vector.<MediaData>();
		}
		
		public function get isFading():Boolean { return videoFading != null; }
		
		public override function get width():Number { return screenW; }
		public override function get height():Number { return screenH; }
		
		public function get currentlyPlaying():String {
			return currentMedia ? currentMedia.videoName : "none";
		}
		
		public function get bandwidth():Number {
			var time:Number = new Date().time;
			if (time - prevBandwidthTime <= 0) { return 0; }
			
			var ns:NetStream;
			if (loadingMedia && loadingMedia.netStream) {
				ns = loadingMedia.netStream;
			} else if (currentMedia && currentMedia.netStream) {
				ns = currentMedia.netStream;
			} else {
				return 0;
			}
			
			// Get current number of bytes loaded.
			var result:Number = ns.bytesLoaded - prevBandwidthBytesLoaded;
			
			// Divide by time passed to get bytes per millisecond.
			result /= (time - prevBandwidthTime);
			
			// Currently bytes per millisecond. Convert to seconds.
			result *= 1000;
			
			prevBandwidthTime = time;
			prevBandwidthBytesLoaded = ns.bytesLoaded;
			return result;
		}
		
		public function get time():Number {
			if (!currentMedia) { return 0; }
			if (currentMedia.currentSegment) {
				//Log.USE_LOG && Log.logmsg("TIME: " + currentMedia.currentTime + " + " + currentMedia.netStream.time + " - " + currentMedia.currentSegment.name + ": " + currentMedia.currentSegment.start + " -- NS STATS: " + nsLoading + " - " + nsSeeking + " - " + currentMedia.loaded);
				return nsSeeking ? currentMedia.currentTime : currentMedia.netStream.time + currentMedia.currentSegment.start;
			} else {
				//Log.USE_LOG && Log.logmsg("TIME: " + currentMedia.currentTime + " - " + currentMedia.netStream.time);
				return nsSeeking ? currentMedia.currentTime : currentMedia.netStream.time;
			}
		}
		
		public function get bufferLength():Number {
			return Number.MAX_VALUE;
		}
		
		public function set volume(value:Number):void {
			volumeControl.volume = value;
		}
		
		public function set maskGapHalfWidth(value:Number):void {
			halfMaskGapFrac = value;
			maskLeftPos = leftMaskX;
			maskRightPos = rightMaskX;
		}
		
		public function set maskLeftPos(value:Number):void { leftMaskX = value; }
		
		public function set maskRightPos(value:Number):void { rightMaskX = value; }
		
		/** Adds and loads video. Only one video at a time will load. */
		public function addVideo(vid:MediaData):void {
			var name:String = vid.videoName;
			vidHash[name] = vid;
			
			if (vid.loadType == Strings.LOAD_STREAMING) {
				if (!vid.url) {
					// No main URL. This one uses segments. Set the base stream url by a segment.
					var segment:MediaSegment = vid.segments[0];
					vid.baseStreamUrl = segment.url.split("mp4:")[0];
					
					// Filter out the base URL for the segments.
					for (var i:int = vid.segments.length - 1; i >= 0; i--) {
						segment = vid.segments[i];
						segment.url = "mp4:" + segment.url.split("mp4:")[1];
					}
				} else if (!vid.baseStreamUrl) {
					// Got a stream link. Split it up.
					var urls:Array = vid.url.split("mp4:");
					vid.baseStreamUrl = urls[0];
					vid.url = "mp4:" + urls[1];
				}
			}
		}
		
		public function showVideo(name:String):void {
			cancelFading();
			
			if (loadingMedia && loadingMedia.videoName == name) {
				// Play the currently loading media? ... yeah, why not? Finish it first.
				mediaFinishedLoading();
			}
			if (currentMedia) {
				if (name == currentMedia.videoName) { 
					// This video is already showing. Do nothing except remove lastMedia reference.
					lastMedia = currentMedia;
					return;
				} else {
					// Remove old currentMedia's event listener. We don't want to be getting statusi from an unused NetStream.
					currentMedia.netStream.removeEventListener(NetStatusEvent.NET_STATUS, handleNSStatus, false);
				}
			}
			
			// Get video data and dimensions.
			var vid:MediaData = vidHash[name];
			vidW = vid.width;
			vidH = vid.height;
			vid.alpha = 1;
			
			// Add netStatus event listener.
			vid.netStream.addEventListener(NetStatusEvent.NET_STATUS, handleNSStatus, false, 0, true);
			
			// Store a reference to the previous media.
			lastMedia = currentMedia;
			currentMedia = vid;
		}
		
		/** Fades the video based on time, in seconds. */
		public function fadeVideo(name:String, from:Number = 0, to:Number = 1, time:Number = 1):void {
			if (vidHash[name] == videoFading) { return; }
			videoFading = vidHash[name];
			vidHash[name].alpha = from;
			videoFadeTarget = to;
			videoFadeTween = TweenUtil.fade(videoFading, time, from, to);
		}
		
		/** Abruptedly stops the fading and sets the fade video's alpha to 0. */
		public function cancelFading():void {
			if (videoFading) {
				videoFading.alpha = 0;
				videoFading = null;
				videoFadeTarget = 0;
				TweenUtil.handleTweenComplete(videoFadeTween);
			}
		}
		
		/** Set the anticipated dimensions of the stage. This isn't necessarily stage.stageWidth and stage.stageHeight. */
		public function setStageDimensions(wid:Number, hei:Number):void {
			stageW = wid;
			stageH = hei;
		}
		
		/** Set dimensions of the video. */
		public function setVideoDimensions(name:String, wid:Number, hei:Number):void {
			var vid:MediaData = vidHash[name];
			if (!vid) { return; }
			vid.width = wid;
			vid.height = hei;
			vidW = wid;
			vidH = hei;
		}
		
		/** Set video's alpha. */
		public function setVideoAlpha(name:String, alpha:Number):void {
			var vid:MediaData = vidHash[name];
			if (!vid) { return; }
			vid.alpha = alpha;
		}
		
		/** Set the order of the videos. */
		public function setVideoOrder(order:Vector.<String>):void {
			vidOrder = order;
		}
		
		public function seek(time:Number):void { 
			Log.USE_LOG && Log.logmsg("SEEK TO: " + time + " -- " + nsLoading + " - " + nsSeeking + " - " + nsStopped);
			nsSeekTarget = time;
		}
		
		public function resume():void {
			//Log.USE_LOG && Log.logmsg("RESUME PLAYBACK");
			if (currentMedia) { currentMedia.playing = true; }
		}
		
		public function pause():void {
			//Log.USE_LOG && Log.logmsg("PAUSE PLAYBACK");
			if (currentMedia) { currentMedia.playing = false; }
		}
		
		public function resize(wid:Number, hei:Number):void {
			stageW = wid;
			stageH = hei;
		}
		
		public function update():void { /* OVERRIDE */ }
		
		public function hide():void { /* OVERRIDE */ }
		
		public function show():void { /* OVERRIDE */ }
		
		/** Create and set up NetConnection based on MediaData's urls. */
		protected function setupNetConnection(vid:MediaData):void {
			loadingMedia = vid;
			
			var nc:NetConnection = new NetConnection();
			vid.netConnection = nc;
			
			nc.client = {};
			nc.client.onBWDone = handleBWDone;
			nc.addEventListener(AsyncErrorEvent.ASYNC_ERROR, handleNCAsyncError);
			nc.addEventListener(NetStatusEvent.NET_STATUS, handleNCStatus);
			nc.addEventListener(IOErrorEvent.IO_ERROR, handleNCIOError);
			nc.addEventListener(SecurityErrorEvent.SECURITY_ERROR, handleNCSecurityError);
			
			vid.loaded = false;
			
			//Begin loading the main movie but don't play it yet
			if (vid.baseStreamUrl && vid.baseStreamUrl != "") {
				// For streaming.
				nc.proxyType = "best";
				nc.connect(vid.baseStreamUrl);
			} else {
				// Defaults to progressive if not streaming.
				nc.connect(null);
			}
		}
		
		/** Setup NetStream using NetConnection in MediaData */
		protected function setupNetStream(vid:MediaData):void {
			Log.USE_LOG && Log.logmsg("Setup Net Stream: " + vid.videoName); 
			
			// Start off with reference to currentMedia when streaming.
			progressPercent = 0;
			var ns:NetStream = new NetStream(vid.netConnection);
			
			// Allow domains.
			/*
			Security.allowInsecureDomain("rtmp://wowza.nfb.ca/ralvod");
			Security.allowDomain("rtmp://s334m0dxx0rksm.cloudfront.net");
			Security.allowDomain("rtmp://cdnr-ll1.nfb.ca");
			Security.allowDomain("http://interactive-dev.nfb.ca/invisibleworld");
			*/
			
			ns.checkPolicyFile = true;
			//ns.useHardwareDecoder = true;
			ns.inBufferSeek = true;
			vid.netStream = ns;
			
			ns.client = {};
			ns.client.onMetaData = handleMetaData;

			// Listen for status changes.
			ns.addEventListener(AsyncErrorEvent.ASYNC_ERROR, handleNSAsyncError);
			ns.addEventListener(IOErrorEvent.IO_ERROR, handleNSIOError);
			
			// NetStream is ready. Check loading type.
			if (vid.loadType == Strings.LOAD_STREAMING) {
				// Setup buffer stats for streaming NetStream.
				ns.bufferTime = 10;
				ns.bufferTimeMax = 60;
			}
				
			// Loading for the first time. Don't need status updates when loading. Just get progress on each frame.
			if (USE_FULL_LOAD) {
				addEventListener(Event.ENTER_FRAME, handleNSProgress, false, 0, true);
			} else {
				ns.addEventListener(NetStatusEvent.NET_STATUS, handleNSLoadStatus, false, 0, true);
			}
		}
		
		protected function mediaFinishedLoading():void {
			progressPercent = 0;
			videoReadyToPlay(loadingMedia);
			
			if (hasEventListener(Event.ENTER_FRAME)) {
				removeEventListener(Event.ENTER_FRAME, handleNSProgress, false);
			} else if (loadingMedia.netStream.hasEventListener(NetStatusEvent.NET_STATUS)) {
				loadingMedia.netStream.removeEventListener(NetStatusEvent.NET_STATUS, handleNSLoadStatus, false);
			}
			
			nsLoading = false;
			loadingMedia = null;
			dispatchEvent(new VideoPlayerEvent(VideoPlayerEvent.MEDIA_LOADED, 1));
			
			if (loadingQueue && loadingQueue.length) {
				// Load the next one if the queue, if one exists.
				setupNetConnection(loadingQueue.shift());
			}
		}
		
		protected function videoReadyToPlay(data:MediaData):void {
			Log.USE_LOG && Log.logmsg("VIDEO READY TO PLAY: " + data.playing);
			if (data.playing) {
				data.netStream.resume();
			} else {
				data.netStream.pause();
			}
		}
		
		protected function handleMetaData(metadata:Object):void {
			if (currentMedia && currentMedia.loadType == Strings.LOAD_STREAMING) {
				Log.USE_LOG && Log.logmsg("MetaData duration: " + metadata.duration + " -- " + currentMedia + " / " + currentMedia.baseStreamUrl + " ---- " + currentMedia.url);
			}
			if (metadata.audiochannels || metadata.duration > 100) {
				// Only streams have this data. Update the stream duration.
				Log.USE_LOG && Log.logmsg("What's the duration? " + metadata.duration);
				streamDuration = metadata.duration;
			}
		}
		
		/** Gets bandwidth statistics from NetConnection. */
		protected function handleBWDone(...rest):void {
			Log.USE_LOG && Log.logmsg("Handle Bandwidth Done.");
			if (rest.length > 0) {
				Log.USE_LOG && Log.logmsg("Stream Bandwidth: " + rest[0] + "kbps");
			}
		}
		
		/** NetConnection events */
		protected function handleNCStatus(e:NetStatusEvent):void {
			Log.USE_LOG && Log.logmsg('NC ' + e.info.level + ': ' + e.info.code);
		}
		
		protected function handleNCAsyncError(e:AsyncErrorEvent):void {
			Log.USE_LOG && Log.logmsg("NC AsyncError: " + e.error.message);
		}
		
		protected function handleNCIOError(e:IOErrorEvent):void {
			Log.USE_LOG && Log.logmsg("NC IOError: " + e.type + " - " + e.text);
		}
		
		protected function handleNCSecurityError(e:SecurityErrorEvent):void {
			Log.USE_LOG && Log.logmsg("NC SecurityError: " + e.type + " : " + e.text);
		}
		
		/** NetStream events */
		protected function handleNSAsyncError(e:AsyncErrorEvent):void {
			Log.USE_LOG && Log.logmsg("NS AsyncError: " + e.error.message);
		}
		
		protected function handleNSIOError(e:IOErrorEvent):void {
			Log.USE_LOG && Log.logmsg("NS IOError: " + e.type);
			var stream:NetStream = e.target as NetStream;
			var data:MediaData;
			for (var id:String in vidHash) {
				data = vidHash[id];
				if (data.netStream == stream) {
					dispatchEvent(new VideoPlayerEvent(VideoPlayerEvent.MEDIA_FAILED, data));
					return;
				}
			}
		}
		
		/** Complete load when buffer is full. */
		protected function handleNSLoadStatus(e:NetStatusEvent):void {
			if (e.info.code == "NetStream.Buffer.Full") {
				// Load complete!
				mediaFinishedLoading();
			}
		}
		
		/** Complete load when video has fully loaded. */
		protected function handleNSProgress(e:Event):void {
			if (!loadingMedia) { return; }
			
			var ns:NetStream = loadingMedia.netStream;
			var percent:Number = ns.bytesLoaded / ns.bytesTotal;
			
			if (percent != progressPercent) {
				dispatchEvent(new VideoPlayerEvent(VideoPlayerEvent.MEDIA_PROGRESS, percent));
				
				if (percent == 1) {
					// Load complete!
					mediaFinishedLoading();
				} else {
					// Update progress percent so we don't make rapid calls.
					progressPercent = percent;
				}
			}
		}
		
		protected function handleNSStatus(e:NetStatusEvent):void {
			Log.USE_LOG && Log.logmsg("NS " + (currentMedia ? currentMedia.videoName : "No CurrentMedia") + ' ' + e.info.level + ': ' + e.info.code + " --- LOADING: " + nsLoading + " - SEEKING: " + nsSeeking + " - PLAYING: " + currentMedia.playing + " --   " + currentMedia.currentTime + " -> " + e.target.time);
			
			// Don't run this if simply loading.
			if (!currentMedia) { return; }
			
			if (e.info.code == "NetStream.Play.Start") {
				// Playback started. Usually means video is loaded.
				if (nsLoading) {
					nsLoading = false;
					nsSeeking = false;
					
					// Video loaded. Re-seek to its current time (or new time, if seek was called while nsSeeking was true).
					if (currentMedia.currentSegment) {
						seek((nsSeekTarget >= 0 ? nsSeekTarget : currentMedia.currentTime) + currentMedia.currentSegment.start);
					} else {
						seek(nsSeekTarget >= 0 ? nsSeekTarget : currentMedia.currentTime);
					}
				}
			} else if (e.info.code == "NetStream.Play.Stop" && !nsLoading) {
				if (currentMedia.segments && currentMedia.currentSegment.next) {
					if (currentMedia.loadType == Strings.LOAD_STREAMING) {
						// Netstream.Play.Stop runs when the segment finishes loading, not when the player finishes playing it. We'll need to wait for a bit.
					} else {
						// Segment complete. Play next segment.
						seek(currentMedia.getSegmentByName(currentMedia.currentSegment.next).start);
					}
				} else {
					// Segments or not, media finished playing. Dispatch complete event.
					nsStopped = true;
					dispatchEvent(new VideoPlayerEvent(VideoPlayerEvent.PLAY_COMPLETE));
				}
			} else if (e.info.code == "NetStream.Play.StreamNotFound") {
				// Media load failed. Dispatch event.
				dispatchEvent(new VideoPlayerEvent(VideoPlayerEvent.MEDIA_FAILED, currentMedia));
			} else if (e.info.code == "NetStream.Buffer.Full") {
				// Ensure seeking and buffering is false. When Buffer is full, everything is ready to play.
				nsSeeking = false;
				if (nsBuffering) {
					nsBuffering = false;
					currentMedia.playing ? e.target.resume() : e.target.pause();
				}
			} else if (e.info.code == "NetStream.Buffer.Empty" && !nsBuffering) {
				// Pause while we buffer for a while.
				nsBuffering = true;
				e.target.pause();
			} else if (e.info.code == "NetStream.Seek.Notify") {
				// Seek has begun.
			} else if (e.info.code == "NetStream.Seek.InvalidTime") {
				// Time was invalid, but seek did complete.
				nsSeeking = false;
			} else if (e.info.code == "NetStream.SeekStart.Notify") {
				// Video started seeking. Make sure nsSeeking is true (don't try to render).
				nsSeeking = true;
			} else if (e.info.code == "NetStream.Unpause.Notify" && !nsLoading && nsSeeking) {
				// iOS doesn't dispatch any seek-complete events, so we'll have to use this.
				nsSeeking = false;
			} else if (e.info.code == "NetStream.Buffer.Flush" && currentMedia.loadType == Strings.LOAD_STREAMING) {
				// Stream segment complete. Play next segment.
				if (Math.abs(streamDuration - currentMedia.currentTime) <= 4 && streamDuration != 0) {
					// At the end of the media. Start loading the next one.
					seek(currentMedia.getSegmentByName(currentMedia.currentSegment.next).start);
				}
			}
		}
	}
}