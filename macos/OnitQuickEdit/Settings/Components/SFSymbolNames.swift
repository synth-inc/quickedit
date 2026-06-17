//
//  SFSymbolNames.swift
//  Onit
//
//  Created by Kévin Naudin on 12/18/2025.
//
//  Comprehensive list of SF Symbol names for autocomplete functionality.
//  Source: https://gist.github.com/liyicky/9c049e759cabcf30a11b1ff81305122c
//

import Foundation

/// Provides a comprehensive list of SF Symbol names for search/autocomplete
enum SFSymbolNames {
    /// All available SF Symbol names (subset of most common symbols)
    /// For the complete list of 6000+ symbols, users can type the exact name
    static let allSymbols: [String] = [
        // Numbers
        "0.circle", "0.circle.fill", "0.square", "0.square.fill",
        "1.circle", "1.circle.fill", "1.square", "1.square.fill",
        "2.circle", "2.circle.fill", "2.square", "2.square.fill",
        "3.circle", "3.circle.fill", "3.square", "3.square.fill",
        "4.circle", "4.circle.fill", "4.square", "4.square.fill",
        "5.circle", "5.circle.fill", "5.square", "5.square.fill",
        "6.circle", "6.circle.fill", "6.square", "6.square.fill",
        "7.circle", "7.circle.fill", "7.square", "7.square.fill",
        "8.circle", "8.circle.fill", "8.square", "8.square.fill",
        "9.circle", "9.circle.fill", "9.square", "9.square.fill",

        // Letters
        "a.circle", "a.circle.fill", "a.square", "a.square.fill",
        "b.circle", "b.circle.fill", "b.square", "b.square.fill",
        "c.circle", "c.circle.fill", "c.square", "c.square.fill",

        // Arrows
        "arrow.up", "arrow.up.circle", "arrow.up.circle.fill", "arrow.up.square", "arrow.up.square.fill",
        "arrow.down", "arrow.down.circle", "arrow.down.circle.fill", "arrow.down.square",
        "arrow.left", "arrow.left.circle", "arrow.left.circle.fill", "arrow.left.square",
        "arrow.right", "arrow.right.circle", "arrow.right.circle.fill", "arrow.right.square",
        "arrow.up.left", "arrow.up.right", "arrow.down.left", "arrow.down.right",
        "arrow.uturn.left", "arrow.uturn.right", "arrow.uturn.up", "arrow.uturn.down",
        "arrow.clockwise", "arrow.counterclockwise",
        "arrow.clockwise.circle", "arrow.counterclockwise.circle",
        "arrow.2.squarepath", "arrow.triangle.2.circlepath",
        "arrow.forward", "arrow.backward",
        "arrow.turn.down.left", "arrow.turn.down.right",
        "arrow.turn.up.left", "arrow.turn.up.right",

        // Chevrons
        "chevron.up", "chevron.up.circle", "chevron.up.circle.fill",
        "chevron.down", "chevron.down.circle", "chevron.down.circle.fill",
        "chevron.left", "chevron.left.circle", "chevron.left.circle.fill",
        "chevron.right", "chevron.right.circle", "chevron.right.circle.fill",
        "chevron.left.2", "chevron.right.2",
        "chevron.up.chevron.down", "chevron.compact.up", "chevron.compact.down",

        // Shapes
        "circle", "circle.fill", "circle.slash", "circle.slash.fill",
        "square", "square.fill", "square.slash", "square.slash.fill",
        "rectangle", "rectangle.fill", "rectangle.slash", "rectangle.slash.fill",
        "triangle", "triangle.fill",
        "diamond", "diamond.fill",
        "octagon", "octagon.fill",
        "hexagon", "hexagon.fill",
        "pentagon", "pentagon.fill",
        "seal", "seal.fill",
        "shield", "shield.fill", "shield.slash", "shield.slash.fill",
        "star", "star.fill", "star.circle", "star.circle.fill", "star.square", "star.square.fill",
        "star.slash", "star.slash.fill",
        "heart", "heart.fill", "heart.circle", "heart.circle.fill", "heart.slash", "heart.slash.fill",
        "suit.heart", "suit.heart.fill", "suit.club", "suit.club.fill",
        "suit.spade", "suit.spade.fill", "suit.diamond", "suit.diamond.fill",

        // Checkmarks and X marks
        "checkmark", "checkmark.circle", "checkmark.circle.fill",
        "checkmark.square", "checkmark.square.fill",
        "checkmark.rectangle", "checkmark.rectangle.fill",
        "checkmark.shield", "checkmark.shield.fill",
        "xmark", "xmark.circle", "xmark.circle.fill",
        "xmark.square", "xmark.square.fill",
        "xmark.rectangle", "xmark.rectangle.fill",
        "xmark.shield", "xmark.shield.fill",
        "xmark.octagon", "xmark.octagon.fill",

        // Plus and Minus
        "plus", "plus.circle", "plus.circle.fill", "plus.square", "plus.square.fill",
        "plus.rectangle", "plus.rectangle.fill",
        "minus", "minus.circle", "minus.circle.fill", "minus.square", "minus.square.fill",
        "minus.rectangle", "minus.rectangle.fill",
        "plusminus", "plusminus.circle", "plusminus.circle.fill",

        // Multiply and Divide
        "multiply", "multiply.circle", "multiply.circle.fill", "multiply.square", "multiply.square.fill",
        "divide", "divide.circle", "divide.circle.fill", "divide.square", "divide.square.fill",

        // Equal and Not Equal
        "equal", "equal.circle", "equal.circle.fill", "equal.square", "equal.square.fill",
        "lessthan", "lessthan.circle", "lessthan.circle.fill",
        "greaterthan", "greaterthan.circle", "greaterthan.circle.fill",

        // Question and Exclamation
        "questionmark", "questionmark.circle", "questionmark.circle.fill",
        "questionmark.square", "questionmark.square.fill",
        "exclamationmark", "exclamationmark.circle", "exclamationmark.circle.fill",
        "exclamationmark.triangle", "exclamationmark.triangle.fill",
        "exclamationmark.square", "exclamationmark.square.fill",

        // Info
        "info", "info.circle", "info.circle.fill", "info.square", "info.square.fill",

        // Documents
        "doc", "doc.fill", "doc.circle", "doc.circle.fill",
        "doc.text", "doc.text.fill",
        "doc.plaintext", "doc.plaintext.fill",
        "doc.richtext", "doc.richtext.fill",
        "doc.append", "doc.append.fill",
        "doc.text.magnifyingglass",
        "doc.on.doc", "doc.on.doc.fill",
        "doc.on.clipboard", "doc.on.clipboard.fill",
        "clipboard", "clipboard.fill",
        "note", "note.text",
        "calendar", "calendar.circle", "calendar.circle.fill",
        "calendar.badge.plus", "calendar.badge.minus",

        // Books
        "book", "book.fill", "book.circle", "book.circle.fill",
        "book.closed", "book.closed.fill",
        "books.vertical", "books.vertical.fill",
        "bookmark", "bookmark.fill", "bookmark.circle", "bookmark.circle.fill",
        "bookmark.slash", "bookmark.slash.fill",

        // Folders
        "folder", "folder.fill", "folder.circle", "folder.circle.fill",
        "folder.badge.plus", "folder.badge.minus",
        "folder.badge.questionmark", "folder.badge.person.crop",
        "folder.fill.badge.plus", "folder.fill.badge.minus",

        // Trash
        "trash", "trash.fill", "trash.circle", "trash.circle.fill",
        "trash.slash", "trash.slash.fill",

        // Paperclip
        "paperclip", "paperclip.circle", "paperclip.circle.fill",

        // Magnifying Glass
        "magnifyingglass", "magnifyingglass.circle", "magnifyingglass.circle.fill",
        "plus.magnifyingglass", "minus.magnifyingglass",

        // Mic
        "mic", "mic.fill", "mic.circle", "mic.circle.fill",
        "mic.slash", "mic.slash.fill",

        // Phone
        "phone", "phone.fill", "phone.circle", "phone.circle.fill",
        "phone.arrow.up.right", "phone.arrow.down.left",
        "phone.arrow.right", "phone.down", "phone.down.fill",

        // Video
        "video", "video.fill", "video.circle", "video.circle.fill",
        "video.slash", "video.slash.fill",
        "video.badge.plus", "video.badge.checkmark",

        // Envelope
        "envelope", "envelope.fill", "envelope.circle", "envelope.circle.fill",
        "envelope.open", "envelope.open.fill",
        "envelope.badge", "envelope.badge.fill",

        // Messages
        "message", "message.fill", "message.circle", "message.circle.fill",
        "bubble.left", "bubble.left.fill",
        "bubble.right", "bubble.right.fill",
        "bubble.left.and.bubble.right", "bubble.left.and.bubble.right.fill",
        "quote.bubble", "quote.bubble.fill",
        "captions.bubble", "captions.bubble.fill",
        "text.bubble", "text.bubble.fill",
        "exclamationmark.bubble", "exclamationmark.bubble.fill",
        "plus.bubble", "plus.bubble.fill",

        // Telephone
        "teletype", "teletype.circle", "teletype.circle.fill",
        "teletype.answer", "teletype.answer.circle", "teletype.answer.circle.fill",

        // Bell
        "bell", "bell.fill", "bell.circle", "bell.circle.fill",
        "bell.slash", "bell.slash.fill",
        "bell.badge", "bell.badge.fill",

        // Tags
        "tag", "tag.fill", "tag.circle", "tag.circle.fill",
        "tag.slash", "tag.slash.fill",

        // Bolt
        "bolt", "bolt.fill", "bolt.circle", "bolt.circle.fill",
        "bolt.slash", "bolt.slash.fill",
        "bolt.horizontal", "bolt.horizontal.fill",
        "bolt.heart", "bolt.heart.fill",

        // Eye
        "eye", "eye.fill", "eye.circle", "eye.circle.fill",
        "eye.slash", "eye.slash.fill",

        // Brain
        "brain", "brain.head.profile",

        // Person
        "person", "person.fill", "person.circle", "person.circle.fill",
        "person.crop.circle", "person.crop.circle.fill",
        "person.crop.square", "person.crop.square.fill",
        "person.crop.rectangle", "person.crop.rectangle.fill",
        "person.badge.plus", "person.badge.minus",
        "person.2", "person.2.fill", "person.2.circle", "person.2.circle.fill",
        "person.3", "person.3.fill",
        "person.wave.2", "person.wave.2.fill",

        // Figures
        "figure.stand", "figure.walk", "figure.wave",
        "figure.run", "figure.roll",

        // Hands
        "hand.raised", "hand.raised.fill",
        "hand.raised.slash", "hand.raised.slash.fill",
        "hand.thumbsup", "hand.thumbsup.fill",
        "hand.thumbsdown", "hand.thumbsdown.fill",
        "hand.point.up", "hand.point.up.fill",
        "hand.point.up.left", "hand.point.up.left.fill",
        "hand.point.right", "hand.point.right.fill",
        "hand.point.left", "hand.point.left.fill",
        "hand.point.down", "hand.point.down.fill",
        "hand.wave", "hand.wave.fill",
        "hand.tap", "hand.tap.fill",
        "hand.draw", "hand.draw.fill",
        "hands.clap", "hands.clap.fill",
        "hands.sparkles", "hands.sparkles.fill",

        // Globe
        "globe", "globe.americas", "globe.americas.fill",
        "globe.europe.africa", "globe.europe.africa.fill",
        "globe.asia.australia", "globe.asia.australia.fill",

        // Moon and Sun
        "sun.min", "sun.min.fill", "sun.max", "sun.max.fill",
        "sunrise", "sunrise.fill", "sunset", "sunset.fill",
        "moon", "moon.fill", "moon.circle", "moon.circle.fill",
        "moon.stars", "moon.stars.fill",
        "sparkles", "sparkle",
        "moon.zzz", "moon.zzz.fill",
        "zzz",

        // Cloud
        "cloud", "cloud.fill",
        "cloud.drizzle", "cloud.drizzle.fill",
        "cloud.rain", "cloud.rain.fill",
        "cloud.heavyrain", "cloud.heavyrain.fill",
        "cloud.fog", "cloud.fog.fill",
        "cloud.hail", "cloud.hail.fill",
        "cloud.snow", "cloud.snow.fill",
        "cloud.sleet", "cloud.sleet.fill",
        "cloud.bolt", "cloud.bolt.fill",
        "cloud.bolt.rain", "cloud.bolt.rain.fill",
        "cloud.sun", "cloud.sun.fill",
        "cloud.sun.rain", "cloud.sun.rain.fill",
        "cloud.moon", "cloud.moon.fill",
        "cloud.moon.rain", "cloud.moon.rain.fill",
        "smoke", "smoke.fill",
        "wind", "wind.snow",
        "tornado", "tropicalstorm", "hurricane",
        "thermometer.sun", "thermometer.sun.fill",
        "thermometer.snowflake",
        "thermometer", "thermometer.medium", "thermometer.low", "thermometer.high",
        "humidity", "humidity.fill",

        // Drop
        "drop", "drop.fill", "drop.circle", "drop.circle.fill",
        "drop.triangle", "drop.triangle.fill",

        // Flame
        "flame", "flame.fill", "flame.circle", "flame.circle.fill",

        // Umbrella
        "umbrella", "umbrella.fill",

        // Play
        "play", "play.fill", "play.circle", "play.circle.fill",
        "play.square", "play.square.fill",
        "play.rectangle", "play.rectangle.fill",
        "pause", "pause.fill", "pause.circle", "pause.circle.fill",
        "pause.rectangle", "pause.rectangle.fill",
        "stop", "stop.fill", "stop.circle", "stop.circle.fill",
        "record.circle", "record.circle.fill",
        "playpause", "playpause.fill",
        "backward", "backward.fill", "forward", "forward.fill",
        "backward.end", "backward.end.fill",
        "forward.end", "forward.end.fill",
        "backward.end.alt", "backward.end.alt.fill",
        "forward.end.alt", "forward.end.alt.fill",
        "shuffle", "repeat", "repeat.1",
        "infinity", "infinity.circle", "infinity.circle.fill",

        // Speaker
        "speaker", "speaker.fill",
        "speaker.slash", "speaker.slash.fill",
        "speaker.wave.1", "speaker.wave.1.fill",
        "speaker.wave.2", "speaker.wave.2.fill",
        "speaker.wave.3", "speaker.wave.3.fill",
        "speaker.zzz", "speaker.zzz.fill",

        // Music
        "music.note", "music.note.list",
        "music.mic", "music.mic.circle", "music.mic.circle.fill",
        "music.quarternote.3",
        "goforward.5", "goforward.10", "goforward.15", "goforward.30", "goforward.45", "goforward.60",
        "gobackward.5", "gobackward.10", "gobackward.15", "gobackward.30", "gobackward.45", "gobackward.60",

        // Badge
        "badge.plus.radiowaves.right",
        "badge.plus.radiowaves.forward",

        // Guitar and Instruments
        "guitars", "guitars.fill",
        "pianokeys", "pianokeys.inverse",

        // Photo
        "photo", "photo.fill",
        "photo.circle", "photo.circle.fill",
        "photo.on.rectangle", "photo.on.rectangle.angled",
        "rectangle.on.rectangle", "rectangle.on.rectangle.angled",
        "photo.stack", "photo.stack.fill",

        // Camera
        "camera", "camera.fill", "camera.circle", "camera.circle.fill",
        "camera.shutter.button", "camera.shutter.button.fill",
        "camera.viewfinder", "camera.metering.center.weighted",
        "camera.aperture",

        // Scissors
        "scissors", "scissors.circle", "scissors.circle.fill",

        // Wand
        "wand.and.rays", "wand.and.rays.inverse",
        "wand.and.stars", "wand.and.stars.inverse",
        "crop", "crop.rotate",

        // Dial
        "dial.min", "dial.min.fill",
        "dial.max", "dial.max.fill",

        // Gyroscope
        "gyroscope",

        // Gauge
        "gauge", "gauge.badge.plus", "gauge.badge.minus",
        "speedometer",

        // Metronome
        "metronome", "metronome.fill",

        // Tuningfork
        "tuningfork",

        // Paintbrush
        "paintbrush", "paintbrush.fill",
        "paintbrush.pointed", "paintbrush.pointed.fill",

        // Bandage
        "bandage", "bandage.fill",

        // Ruler
        "ruler", "ruler.fill",

        // Level
        "level", "level.fill",

        // Wrench
        "wrench", "wrench.fill",
        "wrench.and.screwdriver", "wrench.and.screwdriver.fill",

        // Hammer
        "hammer", "hammer.fill",
        "hammer.circle", "hammer.circle.fill",

        // Screwdriver
        "screwdriver", "screwdriver.fill",

        // Eyedropper
        "eyedropper", "eyedropper.halffull", "eyedropper.full",

        // Pencil
        "pencil", "pencil.circle", "pencil.circle.fill",
        "pencil.slash",
        "pencil.line",
        "pencil.and.outline",
        "pencil.tip", "pencil.tip.crop.circle",
        "pencil.tip.crop.circle.badge.plus",
        "pencil.tip.crop.circle.badge.minus",
        "pencil.tip.crop.circle.badge.arrow.forward",
        "lasso",
        "lasso.and.sparkles",

        // Highlighter
        "highlighter",

        // Scribble
        "scribble", "scribble.variable",

        // Eraser
        "eraser", "eraser.fill",
        "eraser.line.dashed", "eraser.line.dashed.fill",

        // Square and Pencil
        "square.and.pencil",
        "rectangle.and.pencil.and.ellipsis",

        // Trash
        "trash", "trash.fill",
        "trash.circle", "trash.circle.fill",
        "trash.slash", "trash.slash.fill",

        // Paperplane
        "paperplane", "paperplane.fill",
        "paperplane.circle", "paperplane.circle.fill",

        // Tray
        "tray", "tray.fill", "tray.circle", "tray.circle.fill",
        "tray.full", "tray.full.fill",
        "tray.and.arrow.up", "tray.and.arrow.up.fill",
        "tray.and.arrow.down", "tray.and.arrow.down.fill",
        "tray.2", "tray.2.fill",

        // Archive
        "archivebox", "archivebox.fill",
        "archivebox.circle", "archivebox.circle.fill",

        // Bin
        "externaldrive", "externaldrive.fill",
        "externaldrive.badge.plus", "externaldrive.badge.minus",
        "externaldrive.badge.checkmark", "externaldrive.badge.xmark",
        "externaldrive.badge.person.crop",
        "externaldrive.badge.icloud",
        "externaldrive.badge.wifi",
        "externaldrive.badge.timemachine",

        // Internaldrive
        "internaldrive", "internaldrive.fill",

        // Opticaldiscdrive
        "opticaldiscdrive", "opticaldiscdrive.fill",

        // Gear
        "gearshape", "gearshape.fill",
        "gearshape.circle", "gearshape.circle.fill",
        "gearshape.2", "gearshape.2.fill",

        // Signature
        "signature",

        // Line Weight
        "lineweight",

        // Person
        "person.crop.circle.badge.plus",
        "person.crop.circle.badge.minus",
        "person.crop.circle.badge.checkmark",
        "person.crop.circle.badge.xmark",
        "person.crop.circle.badge.questionmark",
        "person.crop.circle.badge.exclamationmark",
        "person.crop.circle.badge.moon",
        "person.crop.circle.badge.clock",
        "person.crop.circle.fill.badge.plus",
        "person.crop.circle.fill.badge.minus",
        "person.crop.circle.fill.badge.checkmark",
        "person.crop.circle.fill.badge.xmark",

        // Gift
        "gift", "gift.fill", "gift.circle", "gift.circle.fill",

        // Airplane
        "airplane", "airplane.circle", "airplane.circle.fill",
        "airplane.arrival", "airplane.departure",

        // Car
        "car", "car.fill", "car.circle", "car.circle.fill",
        "car.2", "car.2.fill",
        "bus", "bus.fill", "bus.doubledecker", "bus.doubledecker.fill",
        "tram", "tram.fill", "tram.circle", "tram.circle.fill",
        "bicycle", "bicycle.circle", "bicycle.circle.fill",

        // Bed
        "bed.double", "bed.double.fill",
        "bed.double.circle", "bed.double.circle.fill",

        // Lungs
        "lungs", "lungs.fill",

        // Pills
        "pills", "pills.fill", "pills.circle", "pills.circle.fill",

        // Cross
        "cross", "cross.fill", "cross.circle", "cross.circle.fill",
        "cross.case", "cross.case.fill",

        // Hare
        "hare", "hare.fill",
        "tortoise", "tortoise.fill",

        // Ant
        "ant", "ant.fill", "ant.circle", "ant.circle.fill",

        // Ladybug
        "ladybug", "ladybug.fill",

        // Leaf
        "leaf", "leaf.fill", "leaf.circle", "leaf.circle.fill",
        "leaf.arrow.triangle.circlepath",

        // Building
        "building", "building.fill",
        "building.2", "building.2.fill",
        "building.columns", "building.columns.fill",

        // Lock
        "lock", "lock.fill", "lock.circle", "lock.circle.fill",
        "lock.slash", "lock.slash.fill",
        "lock.open", "lock.open.fill",
        "lock.rotation", "lock.rotation.open",
        "lock.shield", "lock.shield.fill",

        // Key
        "key", "key.fill",
        "key.icloud", "key.icloud.fill",

        // Pin
        "pin", "pin.fill", "pin.circle", "pin.circle.fill",
        "pin.slash", "pin.slash.fill",
        "mappin", "mappin.circle", "mappin.circle.fill",
        "mappin.slash", "mappin.slash.circle", "mappin.slash.circle.fill",
        "mappin.and.ellipse",

        // Map
        "map", "map.fill", "map.circle", "map.circle.fill",

        // Safari
        "safari", "safari.fill",

        // Move
        "move.3d",
        "scale.3d",
        "rotate.3d",
        "torus",

        // Rotate
        "rotate.left", "rotate.left.fill",
        "rotate.right", "rotate.right.fill",

        // Selection
        "selection.pin.in.out",

        // Timeline
        "timeline.selection",

        // CPU
        "cpu", "cpu.fill",

        // Memory
        "memorychip", "memorychip.fill",

        // Opticaldisc
        "opticaldisc", "opticaldisc.fill",

        // TV
        "tv", "tv.fill", "tv.circle", "tv.circle.fill",
        "4k.tv", "4k.tv.fill",
        "music.note.tv", "music.note.tv.fill",
        "play.tv", "play.tv.fill",
        "photo.tv",
        "tv.and.hifispeaker.fill",
        "tv.and.mediabox",

        // Display
        "display", "display.trianglebadge.exclamationmark",
        "display.2",

        // PC
        "pc", "macpro.gen1", "macpro.gen2", "macpro.gen3",
        "server.rack",

        // Laptopcomputer
        "laptopcomputer", "laptopcomputer.and.iphone",
        "macmini", "macmini.fill",
        "macstudio", "macstudio.fill",

        // iMac
        "desktopcomputer",
        "display.and.arrow.down",

        // Headphones
        "headphones", "headphones.circle", "headphones.circle.fill",
        "earbuds", "earbuds.case", "earbuds.case.fill",
        "airpods", "airpodspro", "airpodsmax",

        // Hifispeaker
        "hifispeaker", "hifispeaker.fill",
        "hifispeaker.2", "hifispeaker.2.fill",
        "hifispeaker.and.homepodmini", "hifispeaker.and.homepodmini.fill",
        "homepod", "homepod.fill",
        "homepodmini", "homepodmini.fill",
        "homepod.2", "homepod.2.fill",
        "homepodmini.2", "homepodmini.2.fill",

        // Apple Watch
        "applewatch", "applewatch.watchface",
        "applewatch.radiowaves.left.and.right",
        "applewatch.slash",
        "applewatch.side.right",
        "exclamationmark.applewatch",
        "lock.applewatch",

        // iPhone
        "iphone", "iphone.circle", "iphone.circle.fill",
        "iphone.homebutton", "iphone.homebutton.circle", "iphone.homebutton.circle.fill",
        "iphone.badge.play",
        "iphone.radiowaves.left.and.right",
        "iphone.radiowaves.left.and.right.circle", "iphone.radiowaves.left.and.right.circle.fill",
        "iphone.slash", "iphone.slash.circle", "iphone.slash.circle.fill",
        "lock.iphone",
        "iphone.and.arrow.forward",
        "arrow.turn.up.forward.iphone", "arrow.turn.up.forward.iphone.fill",
        "iphone.rear.camera",

        // iPad
        "ipad", "ipad.landscape",
        "ipad.homebutton", "ipad.homebutton.landscape",
        "ipad.badge.play",
        "ipad.rear.camera",

        // iPod
        "ipod",
        "ipodtouch", "ipodtouch.landscape",
        "ipodtouch.slash",

        // Flip Phone
        "flipphone",
        "candybarphone",

        // Apple TV
        "appletv", "appletv.fill",

        // Homepod
        "hifispeaker.and.homepod", "hifispeaker.and.homepod.fill",

        // Airport
        "airport.express",
        "airport.extreme",
        "airport.extreme.tower",

        // iCloud
        "icloud", "icloud.fill", "icloud.circle", "icloud.circle.fill",
        "icloud.slash", "icloud.slash.fill",
        "exclamationmark.icloud", "exclamationmark.icloud.fill",
        "checkmark.icloud", "checkmark.icloud.fill",
        "xmark.icloud", "xmark.icloud.fill",
        "link.icloud", "link.icloud.fill",
        "bolt.horizontal.icloud", "bolt.horizontal.icloud.fill",
        "person.icloud", "person.icloud.fill",
        "arrow.up.icloud", "arrow.up.icloud.fill",
        "arrow.down.icloud", "arrow.down.icloud.fill",
        "icloud.and.arrow.up", "icloud.and.arrow.up.fill",
        "icloud.and.arrow.down", "icloud.and.arrow.down.fill",

        // WiFi
        "wifi", "wifi.slash", "wifi.circle", "wifi.circle.fill",
        "wifi.exclamationmark",

        // Antenna
        "antenna.radiowaves.left.and.right",
        "antenna.radiowaves.left.and.right.circle",
        "antenna.radiowaves.left.and.right.circle.fill",
        "antenna.radiowaves.left.and.right.slash",

        // Dot Radiowaves
        "dot.radiowaves.left.and.right",
        "dot.radiowaves.right",
        "dot.radiowaves.forward",
        "wave.3.left", "wave.3.left.circle", "wave.3.left.circle.fill",
        "wave.3.right", "wave.3.right.circle", "wave.3.right.circle.fill",
        "wave.3.forward", "wave.3.forward.circle", "wave.3.forward.circle.fill",
        "wave.3.backward", "wave.3.backward.circle", "wave.3.backward.circle.fill",

        // Waveform
        "waveform", "waveform.circle", "waveform.circle.fill",
        "waveform.path.ecg", "waveform.path.ecg.rectangle",
        "waveform.path", "waveform.path.badge.plus", "waveform.path.badge.minus",

        // Power
        "power", "power.circle", "power.circle.fill",
        "power.dotted",
        "togglepower",
        "poweron", "poweroff", "powersleep",

        // Apple Logo
        "applelogo",

        // Lightbulb
        "lightbulb", "lightbulb.fill",
        "lightbulb.circle", "lightbulb.circle.fill",
        "lightbulb.slash", "lightbulb.slash.fill",
        "lightbulb.min", "lightbulb.min.fill",
        "lightbulb.max", "lightbulb.max.fill",

        // AI / Sparkles
        "wand.and.sparkles", "wand.and.sparkles.inverse",
        "sparkle.magnifyingglass",
        "sparkles.rectangle.stack", "sparkles.rectangle.stack.fill",

        // Sparkles
        "sparkles.tv", "sparkles.tv.fill",

        // Square
        "square.and.arrow.up", "square.and.arrow.up.fill",
        "square.and.arrow.up.circle", "square.and.arrow.up.circle.fill",
        "square.and.arrow.up.on.square", "square.and.arrow.up.on.square.fill",
        "square.and.arrow.down", "square.and.arrow.down.fill",
        "square.and.arrow.down.on.square", "square.and.arrow.down.on.square.fill",

        // Rectangle
        "rectangle.portrait", "rectangle.portrait.fill",
        "rectangle.portrait.slash", "rectangle.portrait.slash.fill",
        "rectangle.expand.vertical",
        "rectangle.compress.vertical",
        "rectangle.split.3x1", "rectangle.split.3x1.fill",
        "rectangle.split.3x3", "rectangle.split.3x3.fill",
        "rectangle.split.2x1", "rectangle.split.2x1.fill",
        "rectangle.split.1x2", "rectangle.split.1x2.fill",
        "rectangle.split.2x2", "rectangle.split.2x2.fill",

        // Sidebar
        "sidebar.left",
        "sidebar.right",
        "sidebar.leading",
        "sidebar.trailing",
        "sidebar.squares.left",
        "sidebar.squares.right",
        "sidebar.squares.leading",
        "sidebar.squares.trailing",

        // Macwindow
        "macwindow",
        "macwindow.badge.plus",
        "macwindow.on.rectangle",
        "dock.rectangle",
        "dock.arrow.up.rectangle",
        "dock.arrow.down.rectangle",
        "menubar.rectangle",
        "menubar.dock.rectangle",
        "menubar.dock.rectangle.badge.record",
        "menubar.arrow.up.rectangle",
        "menubar.arrow.down.rectangle",

        // Keyboard
        "keyboard", "keyboard.badge.ellipsis", "keyboard.badge.eye",
        "keyboard.chevron.compact.down", "keyboard.chevron.compact.left",
        "keyboard.onehanded.left", "keyboard.onehanded.right",
        "keyboard.fill",

        // Command
        "command", "command.circle", "command.circle.fill",
        "command.square", "command.square.fill",
        "option", "alt",
        "delete.left", "delete.left.fill",
        "delete.right", "delete.right.fill",
        "clear", "clear.fill",
        "eject", "eject.fill", "eject.circle", "eject.circle.fill",
        "control",
        "projective",
        "mount", "mount.fill",
        "shift", "shift.fill",
        "capslock", "capslock.fill",
        "escape",
        "restart", "restart.circle", "restart.circle.fill",
        "sleep", "sleep.circle", "sleep.circle.fill",
        "wake", "wake.circle", "wake.circle.fill",

        // Globe
        "globe.badge.chevron.backward",

        // Network
        "network",
        "network.badge.shield.half.filled",

        // Text
        "textformat", "textformat.alt",
        "textformat.size", "textformat.size.smaller", "textformat.size.larger",
        "textformat.subscript", "textformat.superscript",
        "bold", "italic", "underline", "strikethrough",
        "bold.italic.underline", "bold.underline",
        "text.alignleft", "text.aligncenter", "text.alignright", "text.justify",
        "text.justify.left", "text.justify.right",
        "text.justify.leading", "text.justify.trailing",
        "text.redaction",
        "list.bullet", "list.bullet.circle", "list.bullet.circle.fill",
        "list.dash", "list.dash.header.rectangle",
        "list.triangle",
        "list.number", "list.star",
        "list.bullet.indent",
        "list.bullet.below.rectangle",
        "list.and.film",
        "line.horizontal.3",
        "line.horizontal.3.decrease", "line.horizontal.3.decrease.circle",
        "line.horizontal.3.circle", "line.horizontal.3.circle.fill",
        "line.horizontal.2.decrease.circle", "line.horizontal.2.decrease.circle.fill",

        // Quote
        "text.quote",
        "text.bubble", "text.bubble.fill",

        // Badge
        "text.badge.plus", "text.badge.minus", "text.badge.checkmark", "text.badge.xmark", "text.badge.star",

        // Insert
        "text.insert",
        "text.append",

        // A
        "a", "abc",
        "textformat.abc",
        "textformat.abc.dottedunderline",

        // Characters
        "character", "character.book.closed", "character.book.closed.fill",
        "character.bubble", "character.bubble.fill",
        "character.cursor.ibeam",
        "character.textbox",
        "a.magnify",
        "a.book.closed", "a.book.closed.fill",

        // Translate
        "textformat.123",
        "123.rectangle", "123.rectangle.fill",
        "character.sutton",
        "character.duployan",
        "character.phonetic",
        "paragraphsign",

        // Number
        "number", "number.circle", "number.circle.fill",
        "number.square", "number.square.fill",

        // Crown
        "crown", "crown.fill",

        // Flag
        "flag", "flag.fill", "flag.circle", "flag.circle.fill",
        "flag.slash", "flag.slash.fill",
        "flag.slash.circle", "flag.slash.circle.fill",
        "flag.badge.ellipsis", "flag.badge.ellipsis.fill",
        "flag.2.crossed", "flag.2.crossed.fill",
        "flag.filled.and.flag.crossed",
        "flag.and.flag.filled.crossed",

        // Location
        "location", "location.fill", "location.circle", "location.circle.fill",
        "location.slash", "location.slash.fill",
        "location.north", "location.north.fill",
        "location.north.circle", "location.north.circle.fill",
        "location.north.line", "location.north.line.fill",

        // Timer
        "timer", "timer.circle", "timer.circle.fill",
        "timer.square",

        // Clock
        "clock", "clock.fill", "clock.circle", "clock.circle.fill",
        "clock.badge.checkmark", "clock.badge.checkmark.fill",
        "clock.badge.xmark", "clock.badge.xmark.fill",
        "clock.badge.exclamationmark", "clock.badge.exclamationmark.fill",
        "clock.badge.questionmark", "clock.badge.questionmark.fill",
        "clock.arrow.circlepath",
        "clock.arrow.2.circlepath",
        "alarm", "alarm.fill",
        "stopwatch", "stopwatch.fill",

        // Game Controller
        "gamecontroller", "gamecontroller.fill",
        "l.joystick", "l.joystick.fill",
        "r.joystick", "r.joystick.fill",
        "l.joystick.press.down", "l.joystick.press.down.fill",
        "r.joystick.press.down", "r.joystick.press.down.fill",
        "l.joystick.tilt.left", "l.joystick.tilt.left.fill",
        "l.joystick.tilt.right", "l.joystick.tilt.right.fill",
        "l.joystick.tilt.up", "l.joystick.tilt.up.fill",
        "l.joystick.tilt.down", "l.joystick.tilt.down.fill",
        "r.joystick.tilt.left", "r.joystick.tilt.left.fill",
        "r.joystick.tilt.right", "r.joystick.tilt.right.fill",
        "r.joystick.tilt.up", "r.joystick.tilt.up.fill",
        "r.joystick.tilt.down", "r.joystick.tilt.down.fill",

        // Controller buttons
        "dpad", "dpad.fill",
        "dpad.up.filled", "dpad.down.filled",
        "dpad.left.filled", "dpad.right.filled",
        "circle.circle", "circle.circle.fill",
        "square.circle", "square.circle.fill",
        "triangle.circle", "triangle.circle.fill",
        "rectangle.roundedtop", "rectangle.roundedtop.fill",
        "rectangle.roundedbottom", "rectangle.roundedbottom.fill",
        "l.rectangle.roundedbottom", "l.rectangle.roundedbottom.fill",
        "r.rectangle.roundedbottom", "r.rectangle.roundedbottom.fill",
        "l1.rectangle.roundedbottom", "l1.rectangle.roundedbottom.fill",
        "r1.rectangle.roundedbottom", "r1.rectangle.roundedbottom.fill",
        "l2.rectangle.roundedtop", "l2.rectangle.roundedtop.fill",
        "r2.rectangle.roundedtop", "r2.rectangle.roundedtop.fill",
        "lb.rectangle.roundedbottom", "lb.rectangle.roundedbottom.fill",
        "rb.rectangle.roundedbottom", "rb.rectangle.roundedbottom.fill",
        "lt.rectangle.roundedtop", "lt.rectangle.roundedtop.fill",
        "rt.rectangle.roundedtop", "rt.rectangle.roundedtop.fill",
        "zl.rectangle.roundedtop", "zl.rectangle.roundedtop.fill",
        "zr.rectangle.roundedtop", "zr.rectangle.roundedtop.fill",

        // Logo PlayStation
        "logo.playstation",
        "logo.xbox",

        // Paintpalette
        "paintpalette", "paintpalette.fill",

        // Cup
        "cup.and.saucer", "cup.and.saucer.fill",
        "takeoutbag.and.cup.and.straw", "takeoutbag.and.cup.and.straw.fill",

        // Fork and Knife
        "fork.knife", "fork.knife.circle", "fork.knife.circle.fill",

        // Cart
        "cart", "cart.fill", "cart.circle", "cart.circle.fill",
        "cart.badge.plus", "cart.badge.minus",
        "cart.fill.badge.plus", "cart.fill.badge.minus",

        // Bag
        "bag", "bag.fill", "bag.circle", "bag.circle.fill",
        "bag.badge.plus", "bag.badge.minus",
        "bag.fill.badge.plus", "bag.fill.badge.minus",

        // Creditcard
        "creditcard", "creditcard.fill", "creditcard.circle", "creditcard.circle.fill",
        "creditcard.and.123",
        "creditcard.trianglebadge.exclamationmark",

        // Giftcard
        "giftcard", "giftcard.fill",

        // Wallet
        "wallet.pass", "wallet.pass.fill",

        // Wonsign
        "wonsign.circle", "wonsign.circle.fill", "wonsign.square", "wonsign.square.fill",
        "yensign.circle", "yensign.circle.fill", "yensign.square", "yensign.square.fill",
        "sterlingsign.circle", "sterlingsign.circle.fill", "sterlingsign.square", "sterlingsign.square.fill",
        "dollarsign.circle", "dollarsign.circle.fill", "dollarsign.square", "dollarsign.square.fill",
        "eurosign.circle", "eurosign.circle.fill", "eurosign.square", "eurosign.square.fill",

        // Banknote
        "banknote", "banknote.fill",

        // Brain
        "brain.filled.head.profile",
        "brain.head.profile.fill",

        // Face Smiling
        "face.smiling", "face.smiling.fill",
        "face.smiling.inverse",
        "face.dashed", "face.dashed.fill",

        // Nose
        "nose", "nose.fill",

        // Mustache
        "mustache", "mustache.fill",

        // Mouth
        "mouth", "mouth.fill",

        // Eyebrow
        "eyebrow",

        // Eyes
        "eyes", "eyes.inverse",

        // Ear
        "ear", "ear.fill",
        "ear.badge.checkmark",
        "ear.trianglebadge.exclamationmark",
        "ear.and.waveform",
        "hearingdevice.ear", "hearingdevice.ear.fill",
        "hand.point.up.braille", "hand.point.up.braille.fill"
    ]
}
