// =================================================================================================
//
//	Starling Framework
//	Copyright 2011-2014 Gamua. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package com.starling.text 
{
    import com.starling.errors.AbstractClassError;

    /** This class is an enumeration of constant values used in setting the 
     *  autoSize property of the TextField class. */ 
    public class TextFieldAutoSize
    {
        /** @private */
        public function TextFieldAutoSize() { throw new AbstractClassError(); }
        
        /** No auto-sizing will happen. */
        public static const NONE:String = "none";
        
        /** The text field will grow to the right; no line-breaks will be added.
         *  The height of the text field remains unchanged. */ 
        public static const HORIZONTAL:String = "horizontal";
        
        /** The text field will grow to the bottom, adding line-breaks when necessary.
          * The width of the text field remains unchanged. */
        public static const VERTICAL:String = "vertical";
        
        /** The text field will grow to the right and bottom; no line-breaks will be added. */
        public static const BOTH_DIRECTIONS:String = "bothDirections";
    }
}