-- Base
import XMonad
import System.Directory
import System.IO (hClose, hPutStr, hPutStrLn)
import System.Exit (exitSuccess)
import qualified XMonad.StackSet as W

    -- Actions
import XMonad.Actions.CopyWindow (kill1)
import XMonad.Actions.CycleWS (Direction1D(..), moveTo, shiftTo, WSType(..), nextScreen, prevScreen)
import XMonad.Actions.MouseResize
import XMonad.Actions.WithAll (sinkAll, killAll)

    -- Data
import Data.Char (isSpace, toUpper)
import Data.Maybe (fromJust)
import Data.Monoid
import Data.Maybe (isJust)
import Data.Tree
import qualified Data.Map as M

    -- Hooks
import XMonad.Hooks.DynamicLog (dynamicLogWithPP, wrap, xmobarPP, xmobarColor, shorten, PP(..))
import XMonad.Hooks.EwmhDesktops  -- for some fullscreen events, also for xcomposite in obs.
import XMonad.Hooks.ManageDocks (avoidStruts, docks, manageDocks, ToggleStruts(..))
import XMonad.Hooks.ManageHelpers (isFullscreen, doFullFloat, doCenterFloat)
import XMonad.Hooks.ServerMode
import XMonad.Hooks.SetWMName
import XMonad.Hooks.StatusBar
import XMonad.Hooks.StatusBar.PP
import XMonad.Hooks.WindowSwallowing
import XMonad.Hooks.WorkspaceHistory

    -- Layouts
import XMonad.Layout.SimplestFloat
import XMonad.Layout.ResizableTile
import XMonad.Layout.Tabbed

    -- Layouts modifiers
import XMonad.Layout.LayoutModifier
import XMonad.Layout.MultiToggle (mkToggle, single, EOT(EOT), (??))
import XMonad.Layout.MultiToggle.Instances (StdTransformers(NBFULL, MIRROR, NOBORDERS))
import XMonad.Layout.NoBorders
import XMonad.Layout.Renamed
import XMonad.Layout.Simplest
import XMonad.Layout.Spacing
import XMonad.Layout.SubLayouts
import XMonad.Layout.WindowArranger (windowArrange, WindowArrangerMsg(..))
import XMonad.Layout.WindowNavigation
import qualified XMonad.Layout.ToggleLayouts as T (toggleLayouts, ToggleLayout(Toggle))
import qualified XMonad.Layout.MultiToggle as MT (Toggle(..))

   -- Utilities
import XMonad.Util.EZConfig (additionalKeysP, mkNamedKeymap)
import XMonad.Util.Hacks (windowedFullscreenFixEventHook, javaHack, trayerAboveXmobarEventHook, trayAbovePanelEventHook, trayerPaddingXmobarEventHook, trayPaddingXmobarEventHook, trayPaddingEventHook)
import XMonad.Util.NamedActions
import XMonad.Util.NamedScratchpad
import XMonad.Util.Run (runProcessWithInput, safeSpawn, spawnPipe)
import XMonad.Util.SpawnOnce

colorBack = "#282c34"
colorFore = "#bbc2cf"

color01 = "#1c1f24"
color02 = "#ff6c6b"
color03 = "#98be65"
color04 = "#da8548"
color05 = "#51afef"
color06 = "#c678dd"
color07 = "#5699af"
color08 = "#202328"
color09 = "#5b6268"
color10 = "#da8548"
color11 = "#4db5bd"
color12 = "#ecbe7b"
color13 = "#3071db"
color14 = "#a9a1e1"
color15 = "#46d9ff"
color16 = "#dfdfdf"

colorTrayer :: String
colorTrayer = "--tint 0x282c34"

myFont :: String
myFont = "xft:SauceCodePro Nerd Font Mono:regular:size=9:antialias=true:hinting=true"

myModMask :: KeyMask
myModMask = mod4Mask        -- Sets modkey to super/windows key

myTerminal :: String
myTerminal = "alacritty"    -- Sets default terminal

myBrowser :: String
myBrowser = "brave "  -- Sets qutebrowser as browser

myEmacs :: String
myEmacs = "emacsclient -c -a 'emacs' "  -- Makes emacs keybindings easier to type

myEditor :: String
myEditor = "emacsclient -c -a 'emacs' "  -- Sets emacs as editor
-- myEditor = myTerminal ++ " -e nvim "    -- Sets neovim as editor

myBorderWidth :: Dimension
myBorderWidth = 2           -- Sets border width for windows

myNormColor :: String       -- Border color of normal windows
myNormColor   = colorBack   -- This variable is imported from Colors.THEME

myFocusColor :: String      -- Border color of focused windows
myFocusColor  = color15     -- This variable is imported from Colors.THEME

windowCount :: X (Maybe String)
windowCount = gets $ Just . show . length . W.integrate' . W.stack . W.workspace . W.current . windowset

myStartupHook :: X ()
myStartupHook = do
  spawn "killall trayer"  -- kill current trayer on each restart
  spawnOnce "setxkbmap -option caps:escape"
  spawnOnce "xsetroot -cursor_name left_ptr"
  spawnOnce "xset r rate 240 50"
  spawnOnce "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
  spawnOnce "volumeicon"
  spawnOnce "blueman-applet"
  spawnOnce "nm-applet"
  spawnOnce "/usr/bin/emacs --daemon" -- emacs daemon for the emacsclient
  spawnOnce "dex -a -s $HOME/.config/autostart"
  spawnOnce "picom --experimental-backends -b"
  spawnOnce "dunst"
  spawnOnce "unclutter"
  spawn ("sleep 2 && trayer --edge top --align right --widthtype request --padding 6 --SetDockType true --SetPartialStrut true --expand true --monitor 1 --transparent true --alpha 0 " ++ colorTrayer ++ " --height 22")
  spawnOnce "xwallpaper --zoom ~/.config/wall.jpg"
  setWMName "LG3D"

myScratchPads :: [NamedScratchpad]
myScratchPads = [ NS "terminal" spawnTerm findTerm manageTerm
                , NS "calculator" spawnCalc findCalc manageCalc
                ]
  where
    spawnTerm  = myTerminal ++ " -t scratchpad"
    findTerm   = title =? "scratchpad"
    manageTerm = customFloating $ W.RationalRect l t w h
               where
                 h = 0.9
                 w = 0.9
                 t = 0.95 -h
                 l = 0.95 -w
    spawnCalc  = "qalculate-gtk"
    findCalc   = className =? "Qalculate-gtk"
    manageCalc = customFloating $ W.RationalRect l t w h
               where
                 h = 0.5
                 w = 0.4
                 t = 0.75 -h
                 l = 0.70 -w

--Makes setting the spacingRaw simpler to write. The spacingRaw module adds a configurable amount of space around windows.
mySpacing :: Integer -> l a -> XMonad.Layout.LayoutModifier.ModifiedLayout Spacing l a
mySpacing i = spacingRaw False (Border i i i i) True (Border i i i i) True

-- Below is a variation of the above except no borders are applied
-- if fewer than two windows. So a single window has no gaps.
mySpacing' :: Integer -> l a -> XMonad.Layout.LayoutModifier.ModifiedLayout Spacing l a
mySpacing' i = spacingRaw True (Border i i i i) True (Border i i i i) True

-- Defining a bunch of layouts, many that I don't use.
-- limitWindows n sets maximum number of windows displayed for layout.
-- mySpacing n sets the gap size around the windows.
tall     = renamed [Replace "tall"]
           $ smartBorders
           $ windowNavigation
           $ addTabs shrinkText myTabTheme
           $ subLayout [] (smartBorders Simplest)
           $ mySpacing 8
           $ ResizableTall 1 (3/100) (1/2) []
monocle  = renamed [Replace "monocle"]
           $ smartBorders
           $ windowNavigation
           $ addTabs shrinkText myTabTheme
           $ subLayout [] (smartBorders Simplest)
           $ Full
floats   = renamed [Replace "floats"]
           $ smartBorders
           $ simplestFloat
tabs     = renamed [Replace "tabs"]
           $ tabbed shrinkText myTabTheme

-- setting colors for tabs layout and tabs sublayout.
myTabTheme = def { fontName            = myFont
                 , activeColor         = color15
                 , inactiveColor       = color08
                 , activeBorderColor   = color15
                 , inactiveBorderColor = colorBack
                 , activeTextColor     = colorBack
                 , inactiveTextColor   = color16
                 }

-- The layout hook
myLayoutHook = avoidStruts
               $ mouseResize
               $ windowArrange
               $ T.toggleLayouts floats
               $ mkToggle (NBFULL ?? NOBORDERS ?? EOT) myDefaultLayout
  where
    myDefaultLayout = withBorder myBorderWidth tall
                                           ||| noBorders monocle
                                           ||| floats
                                           ||| noBorders tabs

-- myWorkspaces = [" 1 ", " 2 ", " 3 ", " 4 ", " 5 ", " 6 ", " 7 ", " 8 ", " 9 "]
myWorkspaces = [" term ", " www ", " dev ", " doc ", " mus ", " chat ", " gfx ", " vid ", " sys "]
myWorkspaceIndices = M.fromList $ zipWith (,) myWorkspaces [1..] -- (,) == \x y -> (x,y)

clickable ws = "<action=xdotool key super+"++show i++">"++ws++"</action>"
    where i = fromJust $ M.lookup ws myWorkspaceIndices

myManageHook :: XMonad.Query (Data.Monoid.Endo WindowSet)
myManageHook = composeAll
  [ className =? "confirm"         --> doFloat
  , className =? "file_progress"   --> doFloat
  , className =? "dialog"          --> doFloat
  , className =? "download"        --> doFloat
  , className =? "error"           --> doFloat
  , className =? "Gimp"            --> doFloat
  , className =? "notification"    --> doFloat
  , className =? "pinentry-gtk-2"  --> doFloat
  , className =? "splash"          --> doFloat
  , className =? "toolbar"         --> doFloat
  , className =? "Yad"             --> doCenterFloat
  , title =? "Oracle VM VirtualBox Manager"   --> doFloat
  , title =? "Order Chain - Market Snapshots" --> doFloat
  , className =? "mpv"             --> doShift ( myWorkspaces !! 7 )
  , className =? "Gimp"            --> doShift ( myWorkspaces !! 8 )
  , className =? "VirtualBox Manager" --> doShift  ( myWorkspaces !! 4 )
  , (className =? "firefox" <&&> resource =? "Dialog") --> doFloat  -- Float Firefox Dialog
  , isFullscreen -->  doFullFloat
  ] <+> namedScratchpadManageHook myScratchPads

subtitle' ::  String -> ((KeyMask, KeySym), NamedAction)
subtitle' x = ((0,0), NamedAction $ map toUpper
                      $ sep ++ "\n-- " ++ x ++ " --\n" ++ sep)
  where
    sep = replicate (6 + length x) '-'

showKeybindings :: [((KeyMask, KeySym), NamedAction)] -> NamedAction
showKeybindings x = addName "Show Keybindings" $ io $ do
  h <- spawnPipe $ "yad --text-info --fontname=\"SauceCodePro Nerd Font Mono 12\" --fore=#46d9ff back=#282c36 --center --geometry=1200x800 --title \"XMonad keybindings\""
  --hPutStr h (unlines $ showKm x) -- showKM adds ">>" before subtitles
  hPutStr h (unlines $ showKmSimple x) -- showKmSimple doesn't add ">>" to subtitles
  hClose h
  return ()

myKeys :: XConfig l0 -> [((KeyMask, KeySym), NamedAction)]
myKeys c =
  --(subtitle "Custom Keys":) $ mkNamedKeymap c $
  let subKeys str ks = subtitle' str : mkNamedKeymap c ks in
  subKeys "Xmonad Essentials"
  [ ("M-C-r", addName "Recompile XMonad"       $ spawn "xmonad --recompile")
  , ("M-S-r", addName "Restart XMonad"         $ spawn "xmonad --restart")
  , ("M-S-q", addName "Quit XMonad"            $ io exitSuccess)
  , ("M-c",   addName "Kill focused window"    $ kill1)
  , ("M-S-b", addName "Toggle bar show/hide"   $ sendMessage ToggleStruts)]

  ^++^ subKeys "Switch to workspace"
  [ ("M-1", addName "Switch to workspace 1"    $ (windows $ W.greedyView $ myWorkspaces !! 0))
  , ("M-2", addName "Switch to workspace 2"    $ (windows $ W.greedyView $ myWorkspaces !! 1))
  , ("M-3", addName "Switch to workspace 3"    $ (windows $ W.greedyView $ myWorkspaces !! 2))
  , ("M-4", addName "Switch to workspace 4"    $ (windows $ W.greedyView $ myWorkspaces !! 3))
  , ("M-5", addName "Switch to workspace 5"    $ (windows $ W.greedyView $ myWorkspaces !! 4))
  , ("M-6", addName "Switch to workspace 6"    $ (windows $ W.greedyView $ myWorkspaces !! 5))
  , ("M-7", addName "Switch to workspace 7"    $ (windows $ W.greedyView $ myWorkspaces !! 6))
  , ("M-8", addName "Switch to workspace 8"    $ (windows $ W.greedyView $ myWorkspaces !! 7))
  , ("M-9", addName "Switch to workspace 9"    $ (windows $ W.greedyView $ myWorkspaces !! 8))]

  ^++^ subKeys "Send window to workspace"
  [ ("M-S-1", addName "Send to workspace 1"    $ (windows $ W.shift $ myWorkspaces !! 0))
  , ("M-S-2", addName "Send to workspace 2"    $ (windows $ W.shift $ myWorkspaces !! 1))
  , ("M-S-3", addName "Send to workspace 3"    $ (windows $ W.shift $ myWorkspaces !! 2))
  , ("M-S-4", addName "Send to workspace 4"    $ (windows $ W.shift $ myWorkspaces !! 3))
  , ("M-S-5", addName "Send to workspace 5"    $ (windows $ W.shift $ myWorkspaces !! 4))
  , ("M-S-6", addName "Send to workspace 6"    $ (windows $ W.shift $ myWorkspaces !! 5))
  , ("M-S-7", addName "Send to workspace 7"    $ (windows $ W.shift $ myWorkspaces !! 6))
  , ("M-S-8", addName "Send to workspace 8"    $ (windows $ W.shift $ myWorkspaces !! 7))
  , ("M-S-9", addName "Send to workspace 9"    $ (windows $ W.shift $ myWorkspaces !! 8))]

  ^++^ subKeys "Window navigation"
  [ ("M-j", addName "Move focus to next window"                       $ windows W.focusDown),
    ("M-k", addName "Move focus to prev window"                       $ windows W.focusUp),
    ("M-S-<Return>", addName "Swap focused window with master window" $ windows W.swapMaster)]

  -- Dmenu scripts (dmscripts)
  ^++^ subKeys "Dmenu scripts"
  [ ("M-r",   addName "Run prompt"                   $ spawn "dmenu_run -p 'Run: '"),
    ("M-p n", addName "Launch network manager"       $ spawn ("networkmanager_dmenu -l 10")),
    ("M-p x", addName "Launch dmenu logout"          $ spawn ("dmenu-logout")),
    ("M-p b", addName "Launch bluetooth dmenu"       $ spawn ("dmenu-bluetooth -l 10")),
    ("M-<Print> s", addName "take ss of screen"      $ spawn ("takeshot --now")),
    ("M-<Print> w", addName "take ss of active win"  $ spawn ("takeshot --win")),
    ("M-<Print> a", addName "take ss selected area"  $ spawn ("takeshot --area")),
    ("M-p e", addName "Launch edit configs dmenu"    $ spawn ("edit-configs"))]

  ^++^ subKeys "Favorite programs"
  [ ("M-<Return>", addName "Launch terminal"    $ spawn (myTerminal)),
    ("M-a w", addName "Launch web browser"      $ spawn (myBrowser)),
    ("M-a c", addName "Launch vs code"          $ spawn ("code")),
    ("M-a s", addName "Launch spotify"          $ spawn ("spotify")),
    ("M-a f", addName "Launch file manager"     $ spawn ("thunar")),
    ("M-a m", addName "Launch mailspring"       $ spawn ("mailspring")),
    ("M-a v", addName "Launch virt-manager"     $ spawn ("virt-manager")),
    ("M-a z", addName "Launch zathura"          $ spawn ("zathura")),
    ("M-a d", addName "Launch discord"          $ spawn ("discord")),
    ("M-a o", addName "Launch office"           $ spawn ("onlyoffice-desktopeditors")),
    ("M-a t", addName "Launch tmux"             $ spawn (myTerminal ++ " -e tmux")),
    ("M-a l", addName "Launch lf"               $ spawn (myTerminal ++ " -e lf")),
    ("M-a n", addName "Launch nvim"             $ spawn (myTerminal ++ " -e nvim"))]

  ^++^ subKeys "Monitors"
  [ ("M-.", addName "Switch focus to next monitor" $ nextScreen)
  , ("M-,", addName "Switch focus to prev monitor" $ prevScreen)]

  -- Switch layouts
  ^++^ subKeys "Switch layouts"
  [ ("M-<Tab>", addName "Switch to next layout"   $ sendMessage NextLayout)
  , ("M-<Space>", addName "Toggle noborders/full" $ sendMessage (MT.Toggle NBFULL) >> sendMessage ToggleStruts)]

  -- Window resizing
  ^++^ subKeys "Window resizing"
  [ ("M-S-h", addName "Shrink window"               $ sendMessage Shrink),
    ("M-S-l", addName "Expand window"               $ sendMessage Expand),
    ("M-S-j", addName "Shrink window vertically"    $ sendMessage MirrorShrink),
    ("M-S-k", addName "Expand window vertically"    $ sendMessage MirrorExpand)]

  -- Floating windows
  ^++^ subKeys "Floating windows"
  [ ("M-f", addName "Toggle float layout"        $ sendMessage (T.Toggle "floats"))
  , ("M-t", addName "Sink a floating window"     $ withFocused $ windows . W.sink)
  , ("M-S-t", addName "Sink all floated windows" $ sinkAll)]

  -- Increase/decrease spacing (gaps)
  ^++^ subKeys "Window spacing (gaps)"
  [ ("C-M1-j", addName "Decrease window spacing" $ decWindowSpacing 4)
  , ("C-M1-k", addName "Increase window spacing" $ incWindowSpacing 4)
  , ("C-M1-h", addName "Decrease screen spacing" $ decScreenSpacing 4)
  , ("C-M1-l", addName "Increase screen spacing" $ incScreenSpacing 4)]

  -- Increase/decrease windows in the master pane or the stack
  ^++^ subKeys "Increase/decrease windows in master pane or the stack"
  [ ("M-i", addName "Increase clients in master pane"   $ sendMessage (IncMasterN 1))
  , ("M-d", addName "Decrease clients in master pane" $ sendMessage (IncMasterN (-1)))]

  -- Sublayouts
  -- This is used to push windows to tabbed sublayouts, or pull them out of it.
  ^++^ subKeys "Sublayouts"
  [ ("M-C-h", addName "pullGroup L"           $ sendMessage $ pullGroup L)
  , ("M-C-l", addName "pullGroup R"           $ sendMessage $ pullGroup R)
  , ("M-C-k", addName "pullGroup U"           $ sendMessage $ pullGroup U)
  , ("M-C-j", addName "pullGroup D"           $ sendMessage $ pullGroup D)
  , ("M-C-m", addName "MergeAll"              $ withFocused (sendMessage . MergeAll))
  -- , ("M-C-u", addName "UnMerge"               $ withFocused (sendMessage . UnMerge))
  , ("M-C-/", addName "UnMergeAll"            $  withFocused (sendMessage . UnMergeAll))
  , ("M-C-.", addName "Switch focus next tab" $  onGroup W.focusUp')
  , ("M-C-,", addName "Switch focus prev tab" $  onGroup W.focusDown')]

  -- Scratchpads
  ^++^ subKeys "Scratchpads"
  [ ("M-s t", addName "Toggle scratchpad terminal"   $ namedScratchpadAction myScratchPads "terminal")
  , ("M-s c", addName "Toggle scratchpad calculator" $ namedScratchpadAction myScratchPads "calculator")]

  -- Emacs (SUPER-e followed by a key)
  ^++^ subKeys "Emacs"
  [ ("M-e r", addName "Restart Emacs Server"     $ spawn ("reload-emacs-server"))
  , ("M-e e", addName "Emacsclient Dashboard"    $ spawn (myEmacs ++ ("--eval '(dashboard-refresh-buffer)'")))
  -- , ("M-e e", addName "Emacsclient Dashboard"    $ spawn (myEmacs))
  , ("M-e a", addName "Emacsclient EMMS (music)" $ spawn (myEmacs ++ ("--eval '(emms)' --eval '(emms-play-directory-tree \"~/Music/\")'")))
  , ("M-e b", addName "Emacsclient Ibuffer"      $ spawn (myEmacs ++ ("--eval '(ibuffer)'")))
  , ("M-e d", addName "Emacsclient Dired"        $ spawn (myEmacs ++ ("--eval '(dired nil)'")))
  , ("M-e i", addName "Emacsclient ERC (IRC)"    $ spawn (myEmacs ++ ("--eval '(erc)'")))
  , ("M-e n", addName "Emacsclient Elfeed (RSS)" $ spawn (myEmacs ++ ("--eval '(elfeed)'")))
  , ("M-e s", addName "Emacsclient Eshell"       $ spawn (myEmacs ++ ("--eval '(eshell)'")))
  , ("M-e v", addName "Emacsclient Vterm"        $ spawn (myEmacs ++ ("--eval '(+vterm/here nil)'")))
  , ("M-e w", addName "Emacsclient EWW Browser"  $ spawn (myEmacs ++ ("--eval '(doom/window-maximize-buffer(eww \"distro.tube\"))'")))]

  -- Multimedia Keys
  ^++^ subKeys "Multimedia keys"
  [ ("<XF86AudioMicMute>", addName "toggle mic mute"         $ spawn "pactl set-source-mute @DEFAULT_SOURCE@ toggle"),
    ("<XF86AudioMute>", addName "toggle audio mute"          $ spawn "pactl set-sink-mute @DEFAULT_SINK@ toggle"),
    ("<XF86AudioLowerVolume>", addName "lower vol"           $ spawn "pactl set-sink-volume @DEFAULT_SINK@ -5%"),
    ("<XF86AudioRaiseVolume>", addName "raise vol"           $ spawn "pactl set-sink-volume @DEFAULT_SINK@ +5%"),
    ("<XF86MonBrightnessUp>", addName "increase brightnes"   $ spawn "xbacklight -inc 10"),
    ("<XF86MonBrightnessDown>", addName "decrease brightnes" $ spawn "xbacklight -dec 10")]

  -- The following lines are needed for named scratchpads.
    where nonNSP          = WSIs (return (\ws -> W.tag ws /= "NSP"))
          nonEmptyNonNSP  = WSIs (return (\ws -> isJust (W.stack ws) && W.tag ws /= "NSP"))

main :: IO ()
main = do
  -- Launching three instances of xmobar on their monitors.
  xmproc0 <- spawnPipe ("xmobar -x 0 $HOME/.config/xmonad/xmobar/xmobar.hs")
  xmproc1 <- spawnPipe ("xmobar -x 1 $HOME/.config/xmonad/xmobar/xmobar.hs")
  xmproc2 <- spawnPipe ("xmobar -x 2 $HOME/.config/xmonad/xmobar/xmobar.hs")
  -- the xmonad, ya know...what the WM is named after!
  xmonad $ addDescrKeys' ((mod4Mask, xK_F1), showKeybindings) myKeys $ ewmh $ docks $ def
    { manageHook         = myManageHook <+> manageDocks
    , handleEventHook    = windowedFullscreenFixEventHook <> swallowEventHook (className =? "Alacritty"  <||> className =? "st-256color" <||> className =? "XTerm") (return True) <> trayerPaddingXmobarEventHook
    , modMask            = myModMask
    , terminal           = myTerminal
    , startupHook        = myStartupHook
    , layoutHook         = myLayoutHook
    , workspaces         = myWorkspaces
    , borderWidth        = myBorderWidth
    , normalBorderColor  = myNormColor
    , focusedBorderColor = myFocusColor
    , logHook = dynamicLogWithPP $  filterOutWsPP [scratchpadWorkspaceTag] $ xmobarPP
        { ppOutput = \x -> hPutStrLn xmproc0 x   -- xmobar on monitor 1
                        >> hPutStrLn xmproc1 x   -- xmobar on monitor 2
                        >> hPutStrLn xmproc2 x   -- xmobar on monitor 3
        , ppCurrent = xmobarColor color03 "" . wrap "[" "]"
          -- Visible but not current workspace
        , ppVisible = xmobarColor color06 "" . clickable
          -- Hidden workspace
        , ppHidden = xmobarColor color03 "" . clickable
          -- Hidden workspaces (no windows)
        , ppHiddenNoWindows = xmobarColor color06 ""  . clickable
          -- Title of active window
        , ppTitle = xmobarColor color16 "" . shorten 60
          -- Separator character
        , ppSep =  "<fc=" ++ color09 ++ "> <fn=1>|</fn> </fc>"
          -- Urgent workspace
        , ppUrgent = xmobarColor color02 "" . wrap "!" "!"
          -- Adding # of windows on current workspace to the bar
        , ppExtras  = [windowCount]
          -- order of things in xmobar
        , ppOrder  = \(ws:l:t:ex) -> [ws,l]++ex++[t]
        }
    }
