package ca.nfb.interactive.display {
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.GraphicsBitmapFill;
	import flash.display.IGraphicsData;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.events.NetStatusEvent;
	import flash.geom.ColorTransform;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	import flash.media.Video;
	import flash.net.NetStream;
	
	import ca.nfb.interactive.data.MediaData;
	import ca.nfb.interactive.data.MediaSegment;
	import ca.nfb.interactive.data.Strings;
	import ca.nfb.interactive.display.events.VideoPlayerEvent;
	import ca.nfb.interactive.log.Log;
	import ca.nfb.interactive.utils.TweenUtil;
	
	public class VideoPlayerBitmapData extends AbstractVideoPlayer {
		private var clipRects:Vector.<Rectangle> = new Vector.<Rectangle>(3);
		
		private static const RESOLUTION:Number = 1;
		
		protected var bmpL:Bitmap;
		protected var bmpM:Bitmap;
		protected var bmpR:Bitmap;
		
		private var ct:ColorTransform;
		
		public function VideoPlayerBitmapData(stage:Stage, wid:Number, hei:Number) {
			super(stage, wid, hei);
			
			screenW = wid;
			screenH = hei;
			
			// Clip rectangles for limiting strain on draw calls.
			clipRects[0] = new Rectangle(0, 0, 0, hei);
			clipRects[1] = new Rectangle(0, 0, wid, hei);
			clipRects[2] = new Rectangle(0, 0, 0, hei);
			
			wid *= RESOLUTION;
			hei *= RESOLUTION;
			
			bmpL = new Bitmap(new BitmapData(wid, hei, false, 0));
			bmpM = new Bitmap(new BitmapData(wid, hei, false, 0));
			bmpR = new Bitmap(new BitmapData(wid, hei, false, 0));
			
			bmpL.scaleX /= RESOLUTION;
			bmpL.scaleY /= RESOLUTION;
			bmpM.scaleX /= RESOLUTION;
			bmpM.scaleY /= RESOLUTION;
			bmpR.scaleX /= RESOLUTION;
			bmpR.scaleY /= RESOLUTION;
		}
		
		/** Returns three bitmaps; left, middle, right. */
		public function get bitmaps():Vector.<Bitmap> {
			return Vector.<Bitmap>([bmpL, bmpM, bmpR]);
		}
		
		public override function get bufferLength():Number {
			return (currentMedia && currentMedia.netStream) ? currentMedia.netStream.bufferLength : 0;
		}
		
		public override function get time():Number {
			if (!currentMedia) { return 0; }
			if (currentMedia.currentSegment) {
				//Log.USE_LOG && Log.logmsg("TIME: " + currentMedia.currentTime + " + " + currentMedia.netStream.time + " - " + currentMedia.currentSegment.name + ": " + currentMedia.currentSegment.start + " -- NS STATS: " + nsLoading + " - " + nsSeeking + " - " + currentMedia.loaded);
				return currentMedia.currentTime + currentMedia.currentSegment.start;
			} else {
				return currentMedia.currentTime;
			}
		}
		
		public override function set volume(value:Number):void {
			super.volume = value;
			for (var id:String in vidHash) {
				vidHash[id].netStream.soundTransform = volumeControl;
			}
		}
		
		public override function addVideo(vid:MediaData):void {
			super.addVideo(vid);
			
			// Only one video will load at a time.
			if (!loadingMedia) {
				setupNetConnection(vid);
			} else {
				loadingQueue.push(vid);
			}
		}
		
		public override function showVideo(name:String):void {
			super.showVideo(name);
			
			// Clear the screen.
			var rect:Rectangle = new Rectangle(0, 0, bmpM.bitmapData.width, bmpM.bitmapData.height);
			bmpL.bitmapData.fillRect(rect, 0x000000);
			bmpM.bitmapData.fillRect(rect, 0x000000);
			bmpR.bitmapData.fillRect(rect, 0x000000);
			
			if (lastMedia && lastMedia.netStream) {
				// Pause the last media.
				lastMedia.netStream.pause();
			}
			
			if (currentMedia.loadType == Strings.LOAD_STREAMING) {
				// Streaming videos require some wait time.
				nsLoading = true;
				nsSeeking = false;
			}
			
			if (currentMedia.loaded) {
				// NetConnection, NetStream, and video are loaded. Ready to play.
				videoReadyToPlay(currentMedia);
				nsLoading = false;
				nsSeeking = false;
			}
			
			vidW = currentMedia.video.width;
			vidH = currentMedia.video.height;
			
			resize(stageW, stageH);
		}
		
		public override function set maskLeftPos(value:Number):void {
			super.maskLeftPos = value;
			
			// Update the clip rectangles based on new mask position.
			var gapWid:Number = halfMaskGapFrac * screenW;
			var rect:Rectangle = clipRects[0];
			rect.width = leftMaskX + gapWid;
			rect = clipRects[1];
			rect.x = leftMaskX - gapWid;
			rect.width = rightMaskX + gapWid - rect.x;
		}
		
		public override function set maskRightPos(value:Number):void {
			super.maskRightPos = value;
			
			// Update the clip rectangles based on new mask position.
			var gapWid:Number = halfMaskGapFrac * screenW;
			var rect:Rectangle = clipRects[1];
			rect.width = rightMaskX + gapWid - rect.x;
			rect = clipRects[2];
			rect.x = rightMaskX - gapWid;
			rect.width = bmpM.width - rect.x;
		}
		
		public override function resize(wid:Number, hei:Number):void {
			super.resize(wid, hei);
			dispatchEvent(new VideoPlayerEvent(VideoPlayerEvent.RESIZED));
		}
		
		public override function seek(time:Number):void {
			super.seek(time);
			
			if (!nsSeeking && !nsLoading) {
				var ns:NetStream = currentMedia.netStream;
				if (currentMedia.segments) {
					// Uses segments. Check the segment.
					var segment:MediaSegment = currentMedia.getSegmentByTime(time);
					if (segment && segment != currentMedia.currentSegment) {
						// New segment! Switch it off!
						currentMedia.currentSegment = segment;
						loadVideo(currentMedia);
					}
					
					// Seek to the segment time.
					nsSeekTarget = time - segment.start;
					ns.seek(nsSeekTarget);
				} else {
					// Ready for seek.
					if (nsStopped) {
						// Video has stopped. Call "play" to make it work again.
						nsStopped = false;
						Log.USE_LOG && Log.logmsg("--- PLAY " + currentMedia.url);
						ns.play(currentMedia.url);
					}
					
					nsSeekTarget = time;
					ns.seek(time);
				}
				
				if (currentMedia.loadType == Strings.LOAD_STREAMING) {
					// Seeking a stream dispatches an event on completion. Wait for that.
					nsSeeking = true;
				}
				
				currentMedia.currentTime = nsSeekTarget;
			}
		}
		
		public override function hide():void {
			bmpL.visible = false;
			bmpM.visible = false;
			bmpR.visible = false;
		}
		
		public override function show():void {
			bmpL.visible = true;
			bmpM.visible = true;
			bmpR.visible = true;
		}
		
		public override function update():void {
			if (nsLoading || nsSeeking) { return; }
			if (nsSeekTarget >= 0) {
				if (Math.abs(currentMedia.netStream.time - nsSeekTarget) > 2) {
					// NetStream hasn't finished seeking yet.
					return;
				} else {
					nsSeekTarget = -1;
				}
			}
			
			draw(currentMedia);
			if (videoFading) { draw(videoFading); }
		}
		
		private function draw(vid:MediaData):void {
			vid.currentTime = vid.netStream.time;
			
			var mat:Matrix = new Matrix();
			mat.scale(screenW / vid.width, screenH / vid.height);
			
			ct = (vid.alpha != 1) ? new ColorTransform(1, 1, 1, vid.alpha) : null;
			
			var container:Sprite = vid.videoContainer;
			if (container.graphics.hasOwnProperty("readGraphicsData")) {
				Log.USE_LOG && Log.logmsg("--- using ReadGraphicsData");
				var data:Vector.<IGraphicsData> = container.graphics.readGraphicsData();
				if (data.length > 0) {
					var buffer:BitmapData = GraphicsBitmapFill(data[0]).bitmapData;
					try {
						switch(vid.playType) {
							case MediaData.TYPE_FULL_VID:
								bmpM.bitmapData.draw(buffer, mat, ct);
								break;
							case MediaData.TYPE_MASKED_VID:
								bmpL.bitmapData.draw(buffer, mat, ct, null, clipRects[0]);
								bmpM.bitmapData.draw(buffer, mat, ct, null, clipRects[1]);
								bmpR.bitmapData.draw(buffer, mat, ct, null, clipRects[2]);
								break;
							case MediaData.TYPE_SEGMENTED_VID:
								mat.scale(2, 2);
								bmpL.bitmapData.draw(buffer, mat, ct, null, clipRects[0]);
								mat.translate(-screenW, 0);
								bmpM.bitmapData.draw(buffer, mat, ct, null, clipRects[1]);
								mat.translate(0, -screenH);
								bmpR.bitmapData.draw(buffer, mat, ct, null, clipRects[2]);
								break;
						}
					} catch (e:Error) {
						// Annoying issue with a security error.
						Log.USE_LOG && Log.logmsg("----- Error: " + e.name + ": " + e.message);
					}
				}
			} else {
				Log.USE_LOG && Log.logmsg("--- using direct video rendering");
				var video:Video = vid.video;
				//video.attachNetStream(null);
				//vid.netStream.play(null);
				try {
					switch(vid.playType) {
						case MediaData.TYPE_FULL_VID:
							bmpM.bitmapData.draw(video, mat, ct);
							break;
						case MediaData.TYPE_MASKED_VID:
							bmpL.bitmapData.draw(video, mat, ct, null, clipRects[0]);
							bmpM.bitmapData.draw(video, mat, ct, null, clipRects[1]);
							bmpR.bitmapData.draw(video, mat, ct, null, clipRects[2]);
							break;
						case MediaData.TYPE_SEGMENTED_VID:
							mat.scale(2, 2);
							bmpL.bitmapData.draw(video, mat, ct, null, clipRects[0]);
							mat.translate(-screenW, 0);
							bmpM.bitmapData.draw(video, mat, ct, null, clipRects[1]);
							mat.translate(0, -screenH);
							bmpR.bitmapData.draw(video, mat, ct, null, clipRects[2]);
							break;
					}
				} catch (e:Error) {
					// Annoying issue with a security error.
					Log.USE_LOG && Log.logmsg("--- Error: " + e.name + ": " + e.message);
				}
				//vid.netStream.play("");
				//video.attachNetStream(vid.netStream);
			}
		}
		
		public override function resume():void {
			super.resume();
			if (currentMedia && currentMedia.netStream) { currentMedia.netStream.resume(); }
		}
		
		public override function pause():void {
			super.pause();
			if (currentMedia && currentMedia.netStream) { currentMedia.netStream.pause(); }
		}
		
		public override function fadeVideo(name:String, from:Number=0, to:Number=1, time:Number=1):void {
			super.fadeVideo(name, from, to, time);
			videoFading.netStream.resume();
		}
		
		public override function cancelFading():void {
			if (videoFading) {
				videoFading.netStream.pause();
				videoFading.alpha = 0;
				videoFading = null;
				videoFadeTarget = 0;
				TweenUtil.handleTweenComplete(videoFadeTween);
			}
		}
		
		protected function loadVideo(vid:MediaData):void {
			Log.USE_LOG && Log.logmsg("LoadVideo");
			
			// Play NetStream after applying it to VideoDisplay.
			var ns:NetStream = vid.netStream;
			ns.addEventListener(NetStatusEvent.NET_STATUS, vid.onNetStatus);
			
			nsLoading = true;
			
			if (vid.currentSegment) {
				Log.USE_LOG && Log.logmsg("--- PLAY " + vid.currentSegment.url);
				ns.play(vid.currentSegment.url);
			} else {
				Log.USE_LOG && Log.logmsg("--- PLAY " + vid.url);
				ns.play(vid.url);
			}
			
			prevBandwidthTime = new Date().time;
			prevBandwidthBytesLoaded = 0;
			
			// Set loading video to current video so we can easily operate based on NetStatus.
			if (vid == loadingMedia) {
				// Loading video for the first time. Do not play.
				ns.pause();
			} else {
				// Video has already been loaded (segment?). Play it properly.
				currentMedia = vid;
				ns.addEventListener(NetStatusEvent.NET_STATUS, handleNSStatus);
				
				// Pause and play the video automatically based on playing parameter.
				vid.playing ? ns.resume() : ns.pause();
			}
			
			// Check if video is streaming.
			if (vid.loadType == Strings.LOAD_STREAMING && loadingMedia) {
				// Streaming video doesn't need initial load time. End it here.
				mediaFinishedLoading();
			}
			
			// Create Video object for NetStream.
			if (!vid.video) {
				var video:Video = new Video(vid.width * RESOLUTION, vid.height * RESOLUTION);
				vid.video = video;
				vid.videoContainer = new Sprite();
				vid.videoContainer.addChild(video);
			}
			vid.video.attachNetStream(ns);
		}
		
		protected override function handleNCStatus(e:NetStatusEvent):void {
			super.handleNCStatus(e);
			if (e.info.code == "NetConnection.Connect.Success") {
				// Success connecting to NetConnection. Onto the next step: the netStream.
				setupNetStream(loadingMedia);
				loadVideo(loadingMedia);
			}
		}
		
		protected override function handleNSStatus(e:NetStatusEvent):void {
			super.handleNSStatus(e);
			if (e.info.code == "NetStream.Play.Start") {
				currentMedia.loaded = true;
			} else if (e.info.code == "NetStream.Seek.Complete") {
				// Seek is successful. Only called by streams.
				currentMedia.currentTime = currentMedia.netStream.time;
				nsSeeking = false;
				videoReadyToPlay(currentMedia);
			} else if (e.info.code == "NetStream.Buffer.Full") {
				// Finished loading if the buffer is full.
				nsLoading = false;
			}
		}
	}
}