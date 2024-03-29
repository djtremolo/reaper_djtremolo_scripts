-- Reaper API v7

-- Function to find track by name
function findTrackByName(trackName)
    local numTracks = reaper.CountTracks(0)
    for i = 0, numTracks - 1 do
        local track = reaper.GetTrack(0, i)
        local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if name == trackName then
            return track
        end
    end
    return nil
end


function findItemAtTimePoint(track, timePoint, startFromIndex)
    local itemCount = reaper.CountTrackMediaItems(track)
    for i = startFromIndex, itemCount - 1 do
        local item = reaper.GetTrackMediaItem(track, i)

        local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local itemEnd = itemStart + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

        -- check if the time point is in the middle of this item
        if itemStart <= timePoint and itemEnd > timePoint then
            return reaper.GetTrackMediaItem(track, i), i, (timePoint - itemStart)
        end
    end

    -- if not found
    return nil, 0
end
    


function applyTrackSwitching(trackHost, trackGuest, startTime, endTime)
    -- Check if both tracks are available
    if trackHost and trackGuest then
    else
        reaper.ShowMessageBox("Tracks Host and/or Guest not found, cannot continue.", "Error", 0)
        return
    end

    -- reaper.ShowMessageBox("Tracks found", "Info", 0)

    -- get track information
    local itemHost, itemHostIndex, itemHostTimeDelta = findItemAtTimePoint(trackHost, startTime, 0)
    local itemGuest, itemGuestIndex, itemGuestTimeDelta = findItemAtTimePoint(trackGuest, startTime, 0)

    -- requirement: there must be an item at the time selection start point on both tracks
    if itemHost and itemHostIndex and itemHostTimeDelta
        and itemGuest and itemGuestIndex and itemGuestTimeDelta then

        -- items found on tracks, let's find out the track order
        local itemTo, itemToIndex
        local itemFrom, itemFromIndex
        local trackTo

        if itemHostTimeDelta > itemGuestTimeDelta then
            -- item on Host track is the longer one -> direction must be Host->Guest
            itemTo = itemGuest
            itemToIndex = itemGuestIndex
            itemFrom = itemHost
            itemFromIndex = itemHostIndex

            trackTo = trackGuest
            -- reaper.ShowMessageBox("going from Host to Guest", "Info", 0) 
        else
            -- item on track Guest is the longer one -> direction must be Guest->Host
            itemTo = itemHost
            itemToIndex = itemHostIndex
            itemFrom = itemGuest
            itemFromIndex = itemGuestIndex

            trackTo = trackHost
            -- reaper.ShowMessageBox("going from Guest to Host", "Info", 0) 
        end

        -- now as the direction is known and the tracks are automatically mapped, let's start working
        if itemTo and itemFrom then
            -- reaper.ShowMessageBox("splitting To track at startTime", "Info", 0) 
            reaper.SplitMediaItem(itemTo, startTime)    

            -- reaper.ShowMessageBox("splitting From track at endTime", "Info", 0) 
            reaper.SplitMediaItem(itemFrom, endTime)    

            local fadeLength = endTime - startTime

            -- after split, we have next item available on the To track
            local nextItemTo, nextItemToIndex = findItemAtTimePoint(trackTo, startTime, itemToIndex)
        
            -- fade in To track 
            -- reaper.ShowMessageBox("fading in To track", "Info", 0) 
            reaper.SetMediaItemInfo_Value(nextItemTo, "D_FADEINLEN", fadeLength)

            -- fade out From track 
            -- reaper.ShowMessageBox("fading out From track", "Info", 0) 
            reaper.SetMediaItemInfo_Value(itemFrom, "D_FADEOUTLEN", fadeLength)

            -- delete (this has to be the last operation, because the indices change at deletion)
            -- reaper.ShowMessageBox("deleting previous item on To track", "Info", 0) 
            reaper.DeleteTrackMediaItem(trackTo, itemTo)


        else
            reaper.ShowMessageBox("Item picking failed. Prepare first track switching manually and continue from left to right.", "Error", 0) 
            return
        end
    else
        reaper.ShowMessageBox("Item context not valid. Is time selection OK?", "Error", 0)
        return
    end
end



function main()
    reaper.ClearConsole()

    -- Find time selection
    local startTime, endTime = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

    -- Find "Host" and "Guest" tracks
    local hostTrack = findTrackByName("Host")
    local guestTrack = findTrackByName("Guest")

    applyTrackSwitching(hostTrack, guestTrack, startTime, endTime)

    -- finalize by updating the screen
    reaper.UpdateArrange()
end    
    
-- Program starts from here
main()

