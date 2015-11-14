/*
 *      Copyright (C) 2005-2013 Team XBMC
 *      http://www.xbmc.org
 *
 *  This Program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2, or (at your option)
 *  any later version.
 *
 *  This Program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with XBMC; see the file COPYING.  If not, see
 *  <http://www.gnu.org/licenses/>.
 *
 */

#ifndef ES_SUBTITLE_H
#define ES_SUBTITLE_H

#include "elementaryStream.h"

namespace TSDemux
{
  class ES_Subtitle : public ElementaryStream
  {
  public:
    ES_Subtitle(uint16_t pid);
    virtual ~ES_Subtitle();

    virtual void Parse(STREAM_PKT* pkt);
  };
}

#endif /* ES_SUBTITLE_H */
