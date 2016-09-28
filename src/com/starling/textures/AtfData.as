// =================================================================================================
//
//	Starling Framework
//	Copyright 2011-2014 Gamua. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package com.starling.textures
{
    import flash.display3D.Context3DTextureFormat;
    import flash.utils.ByteArray;

    /** A parser for the ATF data format. */
    public class AtfData
    {
        private var mFormat:String;
        private var mWidth:int;
        private var mHeight:int;
        private var mNumTextures:int;
        private var mData:ByteArray;
        
        /** Create a new instance by parsing the given byte array. */
        public function AtfData(data:ByteArray)
        {
            if (!isAtfData(data)) throw new ArgumentError("Invalid ATF data");
            
            if (data[6] == 255) data.position = 12; // new file version
            else                data.position =  6; // old file version
            
            switch (data.readUnsignedByte())
            {
                case 0:
                case 1: mFormat = Context3DTextureFormat.BGRA; break;
                case 2:
                case 3: mFormat = Context3DTextureFormat.COMPRESSED; break;
                case 4:
                case 5: mFormat = "compressedAlpha"; break; // explicit string to stay compatible 
                                                            // with older versions
                default: throw new Error("Invalid ATF format");
            }
            
            mWidth = Math.pow(2, data.readUnsignedByte()); 
            mHeight = Math.pow(2, data.readUnsignedByte());
            mNumTextures = data.readUnsignedByte();
            mData = data;
            
            // version 2 of the new file format contains information about
            // the "-e" and "-n" parameters of png2atf
            
            if (data[5] != 0 && data[6] == 255)
            {
                var emptyMipmaps:Boolean = (data[5] & 0x01) == 1;
                var numTextures:int  = data[5] >> 1 & 0x7f;
                mNumTextures = emptyMipmaps ? 1 : numTextures;
            }
        }
        
        public static function isAtfData(data:ByteArray):Boolean
        {
            if (data.length < 3) return false;
            else
            {
                var signature:String = String.fromCharCode(data[0], data[1], data[2]);
                return signature == "ATF";
            }
        }
        
        public function get format():String { return mFormat; }
        public function get width():int { return mWidth; }
        public function get height():int { return mHeight; }
        public function get numTextures():int { return mNumTextures; }
        public function get data():ByteArray { return mData; }
    }
}