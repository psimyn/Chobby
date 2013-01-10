Screen = Object:Inherit{
  classname = 'screen',
  x         = 0,
  y         = 0,
  width     = 0,
  height    = 0,

  preserveChildrenOrder = true,

  activeControl = nil,
  focusedControl = nil,
  hoveredControl = nil,
  currentTooltip = nil,
  _lastHoveredControl = nil,

  _lastClicked = Spring.GetTimer(),
  _lastClickedX = 0,
  _lastClickedY = 0,
}

local this = Screen
local inherited = this.inherited

--//=============================================================================

function Screen:New(obj)
  local vsx,vsy = gl.GetViewSizes()
  if ((obj.width or -1) <= 0) then
    obj.width = vsx
  end
  if ((obj.height or -1) <= 0) then
    obj.height = vsy
  end

  obj = inherited.New(self,obj)

  TaskHandler.RequestGlobalDispose(obj)
  obj:RequestUpdate()

  return obj
end


function Screen:OnGlobalDispose(obj)
  if (UnlinkSafe(self.activeControl) == obj) then
    self.activeControl = nil
  end

  if (UnlinkSafe(self.hoveredControl) == obj) then
    self.hoveredControl = nil
  end

  if (UnlinkSafe(self._lastHoveredControl) == obj) then
    self._lastHoveredControl = nil
  end

  if (UnlinkSafe(self.focusedControl) == obj) then
    self.focusedControl = nil
  end
end

--//=============================================================================

--FIXME add new coordspace Device (which does y-invert)

function Screen:ParentToLocal(x,y)
  return x, y
end


function Screen:LocalToParent(x,y)
  return x, y
end


function Screen:LocalToScreen(x,y)
  return x, y
end


function Screen:ScreenToLocal(x,y)
  return x, y
end


function Screen:ScreenToClient(x,y)
  return x, y
end


function Screen:ClientToScreen(x,y)
  return x, y
end


function Screen:IsRectInView(x,y,w,h)
	return
		(x <= self.width) and
		(x + w >= 0) and
		(y <= self.height) and
		(y + h >= 0)
end

--//=============================================================================

function Screen:Update(...)
	--//FIXME create a passive MouseMove event and use it instead?
	self:RequestUpdate()
	local hoveredControl = UnlinkSafe(self.hoveredControl)
	local activeControl = UnlinkSafe(self.activeControl)
	if hoveredControl and (not activeControl) then
		local x, y = Spring.GetMouseState()
		y = select(2,gl.GetViewSizes()) - y
		local cx,cy = hoveredControl:ScreenToLocal(x, y)
		hoveredControl:MouseMove(cx, cy, 0, 0)
	end
end


function Screen:IsAbove(x,y,...)
  local activeControl = UnlinkSafe(self.activeControl)
  if activeControl then
    return true
  end

  y = select(2,gl.GetViewSizes()) - y
  local hoveredControl = inherited.IsAbove(self,x,y,...)

  --// tooltip
  if (UnlinkSafe(hoveredControl) ~= UnlinkSafe(self._lastHoveredControl)) then
    if self._lastHoveredControl then
      self._lastHoveredControl:MouseOut()
    end
    if hoveredControl then
      hoveredControl:MouseOver()
    end

    self.hoveredControl = MakeWeakLink(hoveredControl)
    if (hoveredControl) then
      local control = hoveredControl
      --// find tooltip in hovered control or its parents
      while (not control.tooltip)and(control.parent) do
        control = control.parent
      end
      self.currentTooltip = control.tooltip
    else
      self.currentTooltip = nil
    end
    self._lastHoveredControl = self.hoveredControl
  elseif (self._lastHoveredControl) then
    self.currentTooltip = self._lastHoveredControl.tooltip
  end

  return (not not hoveredControl)
end


function Screen:MouseDown(x,y,...)
  y = select(2,gl.GetViewSizes()) - y
  local activeControl = inherited.MouseDown(self,x,y,...)
  self.activeControl = MakeWeakLink(activeControl)
  if self.focusedControl then
    self.focusedControl.state.focused = false
    self.focusedControl:Invalidate()
  end
  self.focusedControl = nil
  if self.activeControl then
    self.focusedControl = MakeWeakLink(activeControl)
    self.focusedControl.state.focused = true
  end
  return (not not activeControl)
end


function Screen:MouseUp(x,y,...)
  y = select(2,gl.GetViewSizes()) - y
  local activeControl = UnlinkSafe(self.activeControl)
  if activeControl then
    local cx,cy = activeControl:ScreenToLocal(x,y)
    local now = Spring.GetTimer()
    local obj

    local hoveredControl = UnlinkSafe(self.hoveredControl)
    if (hoveredControl == activeControl) then
      --//FIXME send this to controls too, when they didn't `return self` in MouseDown!
      if (math.abs(x - self._lastClickedX)<3) and
         (math.abs(y - self._lastClickedY)<3) and
         (Spring.DiffTimers(now,self._lastClicked) < 0.45 ) --FIXME 0.45 := doubleClick time (use spring config?)
      then
        obj = activeControl:MouseDblClick(cx,cy,...)
      end
      if (obj == nil) then
        obj = activeControl:MouseClick(cx,cy,...)
      end
    end
    self._lastClicked = now
    self._lastClickedX = x
    self._lastClickedY = y

    obj = activeControl:MouseUp(cx,cy,...) or obj
    self.activeControl = nil
    return (not not obj)
  else
    return (not not inherited.MouseUp(self,x,y,...))
  end
end


function Screen:MouseMove(x,y,dx,dy,...)
  y = select(2,gl.GetViewSizes()) - y
  local activeControl = UnlinkSafe(self.activeControl)
  if activeControl then
    local cx,cy = activeControl:ScreenToLocal(x,y)
    local obj = activeControl:MouseMove(cx,cy,dx,-dy,...)
    if (obj==false) then
      self.activeControl = nil
    elseif (not not obj)and(obj ~= activeControl) then
      self.activeControl = MakeWeakLink(obj)
      return true
    else
      return true
    end
  end

  return (not not inherited.MouseMove(self,x,y,dx,-dy,...))
end


function Screen:MouseWheel(x,y,...)
  y = select(2,gl.GetViewSizes()) - y
  local activeControl = UnlinkSafe(self.activeControl)
  if activeControl then
    local cx,cy = activeControl:ScreenToLocal(x,y)
    local obj = activeControl:MouseWheel(cx,cy,...)
    if (obj==false) then
      self.activeControl = nil
    elseif (not not obj)and(obj ~= activeControl) then
      self.activeControl = MakeWeakLink(obj)
      return true
    else
      return true
    end
  end

  return (not not inherited.MouseWheel(self,x,y,...))
end

function Screen:KeyPress(...)
    if self.focusedControl then
      return (not not self.focusedControl:KeyPress(...))
    end
    return (not not inherited:KeyPress(...))
end

--//=============================================================================
