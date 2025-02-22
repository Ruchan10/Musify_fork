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
import org.jaudiotagger.tag.id3.ID3v23Frames;

import java.nio.ByteBuffer;

/**
 * Date Text information frame.
 * <p>The 'Date' frame is a numeric string in the DDMM format containing the date for the recording. This field is always four characters long.
 * <p>Deprecated in v2.4.0
 *
 * <p>For more details, please refer to the ID3 specifications:
 * <ul>
 * <li><a href="http://www.id3.org/id3v2.3.0.txt">ID3 v2.3.0 Spec</a>
 * </ul>
 *
 * @author : Paul Taylor
 * @author : Eric Farng
 * @version $Id$
 */
public class FrameBodyTDAT extends AbstractFrameBodyTextInfo implements ID3v23FrameBody
{
    public static final int DATA_SIZE = 4;
    public static final int DAY_START = 0;
    public static final int DAY_END = 2;
    public static final int MONTH_START = 2;
    public static final int MONTH_END = 4;


    private boolean monthOnly;

    /**
     * Creates a new FrameBodyTDAT datatype.
     */
    public FrameBodyTDAT()
    {
    }

    public FrameBodyTDAT(FrameBodyTDAT body)
    {
        super(body);
    }

    /**
     * Creates a new FrameBodyTDAT datatype.
     *
     * @param textEncoding
     * @param text
     */
    public FrameBodyTDAT(byte textEncoding, String text)
    {
        super(textEncoding, text);
    }

    /**
     * Creates a new FrameBodyTDAT datatype.
     *
     * @param byteBuffer
     * @param frameSize
     * @throws InvalidTagException
     */
    public FrameBodyTDAT(ByteBuffer byteBuffer, int frameSize) throws InvalidTagException
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
        return ID3v23Frames.FRAME_ID_V3_TDAT;
    }

    public boolean isMonthOnly()
    {
        return monthOnly;
    }

    public void setMonthOnly(boolean monthOnly)
    {
        this.monthOnly = monthOnly;
    }
}