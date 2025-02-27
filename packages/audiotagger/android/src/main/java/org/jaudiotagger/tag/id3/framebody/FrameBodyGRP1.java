/*
 *  MusicTag Copyright (C)2003,2004
 *
 *  This library is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser
 *  General Public  License as published by the Free Software Foundation; either version 2.1 of the License,
 *  or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
 *  the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *  See the GNU Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public License along with this library; if not,
 *  you can get a copy from http://www.opensource.org/licenses/lgpl-license.php or write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */
package org.jaudiotagger.tag.id3.framebody;

import org.jaudiotagger.tag.InvalidTagException;
import org.jaudiotagger.tag.id3.ID3v24Frames;

import java.nio.ByteBuffer;

/**
 * iTunes grouping field introduced in 12.5.4.42, before that iTunes used TIT1 as is the norm, but it now uses that
 * for Classical Work. Jaudiotagger maps WORK key to TXXX:WORK for work because TIT1 is in use more for GROUPING.
 * Unfortunately TIT1 is defined in ID3 spec to be used for either which is problematic
 *
 * @author : Paul Taylor
 * @author : Eric Farng
 * @version $Id$
 */
public class FrameBodyGRP1 extends AbstractFrameBodyTextInfo implements ID3v24FrameBody, ID3v23FrameBody
{
    /**
     * Creates a new FrameBodyTBPM datatype.
     */
    public FrameBodyGRP1()
    {
    }

    public FrameBodyGRP1(FrameBodyGRP1 body)
    {
        super(body);
    }

    /**
     * Creates a new FrameBodyTBPM datatype.
     *
     * @param textEncoding
     * @param text
     */
    public FrameBodyGRP1(byte textEncoding, String text)
    {
        super(textEncoding, text);
    }

    /**
     * Creates a new FrameBodyTBPM datatype.
     *
     * @param byteBuffer
     * @param frameSize
     * @throws org.jaudiotagger.tag.InvalidTagException
     */
    public FrameBodyGRP1(ByteBuffer byteBuffer, int frameSize) throws InvalidTagException
    {
        super(byteBuffer, frameSize);
    }


    /**
     * The ID3v2 frame identifier
     *
     * @return the ID3v2 frame identifier  for this frame type
     */
    public String getIdentifier()
    {
        return ID3v24Frames.FRAME_ID_ITUNES_GROUPING;
    }
}