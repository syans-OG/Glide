#[cfg(target_os = "windows")]
use windows::Win32::UI::Input::KeyboardAndMouse::{
    SendInput, INPUT, INPUT_0, INPUT_KEYBOARD, INPUT_MOUSE, KEYBDINPUT, KEYEVENTF_KEYUP,
    MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP, MOUSEEVENTF_MIDDLEDOWN, MOUSEEVENTF_MIDDLEUP,
    MOUSEEVENTF_MOVE, MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP, MOUSEEVENTF_WHEEL, MOUSEINPUT,
    VIRTUAL_KEY, VK_B, VK_D, VK_ESCAPE, VK_F5, VK_LEFT, VK_LWIN, VK_MEDIA_NEXT_TRACK,
    VK_MEDIA_PLAY_PAUSE, VK_MEDIA_PREV_TRACK, VK_MENU, VK_RIGHT, VK_S, VK_SHIFT, VK_TAB,
    VK_VOLUME_DOWN, VK_VOLUME_MUTE, VK_VOLUME_UP, VK_W,
};

#[cfg(target_os = "windows")]
const WHEEL_DELTA: i32 = 120;

#[derive(Debug, Clone, serde::Deserialize, serde::Serialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum KeyAction {
    Next,
    Prev,
    Play,
    Exit,
    Black,
    White,
    #[serde(alias = "VOLUP")]
    VolUp,
    #[serde(alias = "VOLDOWN")]
    VolDown,
    Mute,
    #[serde(alias = "PLAYPAUSE")]
    PlayPause,
    MediaNext,
    MediaPrev,
    TaskView,
    ShowDesktop,
    AppSwitchRight,
    AppSwitchLeft,
    Search,
}

#[cfg(target_os = "windows")]
pub fn simulate_key(action: KeyAction) {
    match action {
        KeyAction::Next => send_virtual_key(VK_RIGHT),
        KeyAction::Prev => send_virtual_key(VK_LEFT),
        KeyAction::Play => send_virtual_key(VK_F5),
        KeyAction::Exit => send_virtual_key(VK_ESCAPE),
        KeyAction::Black => send_virtual_key(VK_B),
        KeyAction::White => send_virtual_key(VK_W),
        KeyAction::VolUp => send_virtual_key(VK_VOLUME_UP),
        KeyAction::VolDown => send_virtual_key(VK_VOLUME_DOWN),
        KeyAction::Mute => send_virtual_key(VK_VOLUME_MUTE),
        KeyAction::PlayPause => send_virtual_key(VK_MEDIA_PLAY_PAUSE),
        KeyAction::MediaNext => send_virtual_key(VK_MEDIA_NEXT_TRACK),
        KeyAction::MediaPrev => send_virtual_key(VK_MEDIA_PREV_TRACK),
        KeyAction::TaskView => send_key_combination(&[VK_LWIN, VK_TAB]),
        KeyAction::ShowDesktop => send_key_combination(&[VK_LWIN, VK_D]),
        KeyAction::AppSwitchRight => send_key_combination(&[VK_MENU, VK_TAB]),
        KeyAction::AppSwitchLeft => send_key_combination(&[VK_MENU, VK_SHIFT, VK_TAB]),
        KeyAction::Search => send_key_combination(&[VK_LWIN, VK_S]),
    }
}

#[cfg(not(target_os = "windows"))]
pub fn simulate_key(_action: KeyAction) {
    println!("[Input] Keystroke simulation is only implemented for Windows target.");
}

#[cfg(target_os = "windows")]
pub fn simulate_mouse_move(dx: i32, dy: i32) {
    unsafe {
        let input = INPUT {
            r#type: INPUT_MOUSE,
            Anonymous: INPUT_0 {
                mi: MOUSEINPUT {
                    dx,
                    dy,
                    mouseData: 0,
                    dwFlags: MOUSEEVENTF_MOVE,
                    time: 0,
                    dwExtraInfo: 0,
                },
            },
        };
        SendInput(&[input], std::mem::size_of::<INPUT>() as i32);
    }
}

#[cfg(not(target_os = "windows"))]
pub fn simulate_mouse_move(_dx: i32, _dy: i32) {}

#[cfg(target_os = "windows")]
pub fn simulate_mouse_click(button: &str) {
    let (down_flag, up_flag) = match button.to_uppercase().as_str() {
        "RIGHT" => (MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP),
        "MIDDLE" => (MOUSEEVENTF_MIDDLEDOWN, MOUSEEVENTF_MIDDLEUP),
        "DOUBLE" => {
            simulate_mouse_click("LEFT");
            // Use a short thread sleep for the double-click delay
            // This is acceptable since it's a one-off 50ms delay
            std::thread::sleep(std::time::Duration::from_millis(50));
            simulate_mouse_click("LEFT");
            return;
        }
        _ => (MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP),
    };

    unsafe {
        let down_input = INPUT {
            r#type: INPUT_MOUSE,
            Anonymous: INPUT_0 {
                mi: MOUSEINPUT {
                    dx: 0,
                    dy: 0,
                    mouseData: 0,
                    dwFlags: down_flag,
                    time: 0,
                    dwExtraInfo: 0,
                },
            },
        };

        let up_input = INPUT {
            r#type: INPUT_MOUSE,
            Anonymous: INPUT_0 {
                mi: MOUSEINPUT {
                    dx: 0,
                    dy: 0,
                    mouseData: 0,
                    dwFlags: up_flag,
                    time: 0,
                    dwExtraInfo: 0,
                },
            },
        };

        SendInput(&[down_input, up_input], std::mem::size_of::<INPUT>() as i32);
    }
}

#[cfg(not(target_os = "windows"))]
pub fn simulate_mouse_click(_button: &str) {}

#[cfg(target_os = "windows")]
pub fn simulate_mouse_scroll(dy: i32) {
    unsafe {
        let input = INPUT {
            r#type: INPUT_MOUSE,
            Anonymous: INPUT_0 {
                mi: MOUSEINPUT {
                    dx: 0,
                    dy: 0,
                    mouseData: (dy * (WHEEL_DELTA / 3)) as u32,
                    dwFlags: MOUSEEVENTF_WHEEL,
                    time: 0,
                    dwExtraInfo: 0,
                },
            },
        };
        SendInput(&[input], std::mem::size_of::<INPUT>() as i32);
    }
}

#[cfg(not(target_os = "windows"))]
pub fn simulate_mouse_scroll(_dy: i32) {}

#[cfg(target_os = "windows")]
fn send_virtual_key(vk: VIRTUAL_KEY) {
    unsafe {
        let down_input = INPUT {
            r#type: INPUT_KEYBOARD,
            Anonymous: INPUT_0 {
                ki: KEYBDINPUT {
                    wVk: vk,
                    wScan: 0,
                    dwFlags: Default::default(),
                    time: 0,
                    dwExtraInfo: 0,
                },
            },
        };

        let up_input = INPUT {
            r#type: INPUT_KEYBOARD,
            Anonymous: INPUT_0 {
                ki: KEYBDINPUT {
                    wVk: vk,
                    wScan: 0,
                    dwFlags: KEYEVENTF_KEYUP,
                    time: 0,
                    dwExtraInfo: 0,
                },
            },
        };

        SendInput(&[down_input, up_input], std::mem::size_of::<INPUT>() as i32);
    }
}

#[cfg(target_os = "windows")]
fn send_key_combination(keys: &[VIRTUAL_KEY]) {
    unsafe {
        let mut inputs = Vec::with_capacity(keys.len() * 2);

        // 1. Press all down
        for &k in keys {
            inputs.push(INPUT {
                r#type: INPUT_KEYBOARD,
                Anonymous: INPUT_0 {
                    ki: KEYBDINPUT {
                        wVk: k,
                        wScan: 0,
                        dwFlags: Default::default(),
                        time: 0,
                        dwExtraInfo: 0,
                    },
                },
            });
        }

        // 2. Release all in reverse order
        for &k in keys.iter().rev() {
            inputs.push(INPUT {
                r#type: INPUT_KEYBOARD,
                Anonymous: INPUT_0 {
                    ki: KEYBDINPUT {
                        wVk: k,
                        wScan: 0,
                        dwFlags: KEYEVENTF_KEYUP,
                        time: 0,
                        dwExtraInfo: 0,
                    },
                },
            });
        }

        SendInput(&inputs, std::mem::size_of::<INPUT>() as i32);
    }
}
