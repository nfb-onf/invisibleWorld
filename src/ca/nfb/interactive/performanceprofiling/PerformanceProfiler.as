﻿package ca.nfb.interactive.performanceprofiling {	import flash.events.Event;	import flash.events.EventDispatcher;	import flash.events.IEventDispatcher;	import flash.net.NetStream;		import ca.nfb.interactive.log.Log;		public class PerformanceProfiler extends EventDispatcher {		public static const QUALITY_LOW:int = 0		public static const QUALITY_MED:int = 1		public static const QUALITY_HIGH:int = 2				private static var instance:PerformanceProfiler = new PerformanceProfiler();		private var fpsWatcher:FPSWatcher = FPSWatcher.getInstance();		private var bandwidth:BandwidthProfiler = BandwidthProfiler.getInstance();				private static var quality:int = QUALITY_MED;				public function PerformanceProfiler(target:IEventDispatcher=null) {			if (instance) {				throw new Error("PERFORMANCEPROFILER ALREADY EXISTS")			}		}		public static function getInstance():PerformanceProfiler {			return instance		}		public static function getAverageFps():int {			return getInstance().intGetFps()		}		private function intGetFps():uint {			return fpsWatcher.averageFPS		}		public static function getBandwidth():int {			//returns kBps			return getInstance().intGetBandwidth()		}		private function intGetBandwidth():uint {			//returns kBps					return bandwidth.bandwidth		}		public static function getQuality():int {			//Log.USE_LOG && Log.logmsg("[PerformanceProfiler] ", quality, "[bandwidth] ", getInstance().intGetBandwidth(), "[averageFps] ", getInstance().intGetFps() )			return quality		}		private function determineBandFrameQuality(e:Event):void {						var bandQuality:int			var frameQuality:int						if (getBandwidth() >= PerformanceTreshholds.BANDWIDTH_HIGH) {				bandQuality = QUALITY_HIGH;			} else if (getBandwidth() <= PerformanceTreshholds.BANDWIDTH_MED) {				bandQuality = QUALITY_MED;			} else if (getBandwidth() <= PerformanceTreshholds.BANDWIDTH_LOW) {				bandQuality = QUALITY_LOW;			}						if (getAverageFps() >= PerformanceTreshholds.FRAME_HIGH) {				frameQuality = QUALITY_HIGH;			} else if (getAverageFps() <= PerformanceTreshholds.FRAME_MED) {				frameQuality = QUALITY_MED;			} else if (getAverageFps() <= PerformanceTreshholds.FRAME_LOW) {				frameQuality = QUALITY_LOW;			}						if (getInstance().fpsWatcher.fpsIsRunning) {				//Log.USE_LOG && Log.logmsg("[PerformanceProfiler] NOTICE: FPS AND BANDWIDTH ONLY REPORTING, bandQuality, frameQuality", bandQuality, frameQuality);				quality = Math.min(bandQuality, frameQuality);			} else {				//Log.USE_LOG && Log.logmsg("[PerformanceProfiler] NOTICE: BANDWIDTH ONLY REPORTING bandQuality", bandQuality);				quality = bandQuality;			}		//			Log.USE_LOG && Log.logmsg("[PerformanceProfiler] determineQuality, getBandwidth() ", getBandwidth());//			Log.USE_LOG && Log.logmsg("[PerformanceProfiler] determineQuality, getAverageFps() ", getAverageFps());//			Log.USE_LOG && Log.logmsg("[PerformanceProfiler] determineQuality, bandQuality", bandQuality);//			Log.USE_LOG && Log.logmsg("[PerformanceProfiler] determineQuality, frameQuality", frameQuality);//			Log.USE_LOG && Log.logmsg("[PerformanceProfiler] determineQuality, quality", quality);		}				public static function determineFrameQuality():int {						var frameQuality:int;						if (getAverageFps() >= PerformanceTreshholds.FRAME_HIGH) {				frameQuality = QUALITY_HIGH;			} else if (getAverageFps() >= PerformanceTreshholds.FRAME_MED) {				frameQuality = QUALITY_MED;			} else if (getAverageFps() >= PerformanceTreshholds.FRAME_LOW) {				frameQuality = QUALITY_LOW;			}						return frameQuality;		}				public static function set fpsSampleTime(seconds:Number):void {			getInstance().fpsWatcher.sampleTime = seconds;		}				public static function getfpsSampleTime():Number {			return getInstance().fpsWatcher.sampleTime;		}				public static function fpsStart():void {			getInstance().fpsWatcher.start();		}				public static function fpsStop():void {			getInstance().fpsWatcher.stop();		}				public static function startDownLoad(evtd:EventDispatcher):void {			getInstance().intStartDownload(evtd)		}		private function intStartDownload(evtd:EventDispatcher):void {			getInstance().bandwidth.addEventListener(Event.COMPLETE, determineBandFrameQuality, false, 0, true)						if (evtd is NetStream) {				bandwidth.handleNetStreams(evtd as NetStream)			} else {				//Log.USE_LOG && Log.logmsg("is a loader");				bandwidth.handleLoaders(evtd)			}		}	}}