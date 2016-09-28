﻿package ca.nfb.interactive.performanceprofiling {			import ca.nfb.interactive.performanceprofiling.events.FpsUpdateEvent;		import flash.display.Sprite;	import flash.events.Event;	import flash.utils.getTimer;		internal class FPSWatcher extends Sprite {		private const NUM_FRAMES_TO_AVERAGE:uint = 10;				private static var allowInstanceCreation:Boolean = false;		private static var instance:FPSWatcher;				private var callers:Array = new Array();		private var minFrames:Array = new Array();				private var frameCounter:uint = 0;		private var lastTime:uint = 0;		private var _sampleTime:uint = 1000;		private var numSamples:uint = 0;				private var _averageFPS:Number = 25;				private var _fpsIsRunning:Boolean ;				public function FPSWatcher() {			if (!allowInstanceCreation) {				throw new Error("YOU MUST GET THE INSTANCE OF FPSWatcher using get instance");			}		}				internal function start():void {			_fpsIsRunning=true;			this.addEventListener(Event.ENTER_FRAME, mainLoop);		}				internal function stop():void {			_fpsIsRunning=false;			this.removeEventListener(Event.ENTER_FRAME, mainLoop);		}				internal static function getInstance():FPSWatcher {			if (!instance) {				allowInstanceCreation = true;								instance = new FPSWatcher();								allowInstanceCreation = false;			}						return instance;		}				internal function set sampleTime(seconds:Number):void {			_sampleTime = 1000 * seconds;		}				internal function get sampleTime():Number {			return _sampleTime / 1000;		}				internal function get averageFPS():uint {			return _averageFPS;		}				internal function get fpsIsRunning():Boolean {			return _fpsIsRunning;		}				internal function addWatch(caller:*, minFrameRate:uint):void {			callers.push(caller);			minFrames.push(minFrameRate);		}				private function mainLoop(ev:Event):void {			var newTime:uint = getTimer();						frameCounter++;						var actualInterval:uint = newTime - lastTime;						if (actualInterval >= _sampleTime) {				var fps:uint = Math.floor(frameCounter / (actualInterval / 1000));								frameCounter = 0;				lastTime = getTimer();								numSamples++;								var nAverage:Number = _averageFPS * ((numSamples - 1) / numSamples) + fps * (1 / numSamples);								if (_averageFPS != nAverage) {					//weighed average (pAvg*numsamples+nSample*1)/(numsamples+1)					_averageFPS = nAverage;										dispatchEvent(new FpsUpdateEvent(FpsUpdateEvent.FPS_UPDATED, _averageFPS));				}			}		}	}}