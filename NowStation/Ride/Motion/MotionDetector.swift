import Foundation

/**
 * 움직임 판단 기준값. Android와 같은 값(합성 신호로 정함)이라 실제 지하철에서 다시 맞춰야 한다.
 * 근거: 지하철 가속·감속은 보통 0.5~1.3 m/s²로 몇~수십 초 이어진다. 걷기는 1~3 m/s²로 1초에 두 번쯤 흔들린다.
 */
struct MotionRules {
    /** 이 이상 꾸준히 밀리면 가속(감속) 중으로 본다(m/s²). */
    var pushThreshold = 0.25
    /** 이 아래면 꾸준한 밀림이 없다고 보고 중력을 따라간다(m/s²). */
    var pushEndThreshold = 0.15
    /** 꾸준한 밀림이 이만큼 이어져야 출발·감속으로 인정한다(초). */
    var minPushSeconds = 4.0
    /** 짧은 흔들림이 이보다 크면 걷는 중·폰을 만지는 중이라 판단하지 않는다(m/s²). */
    var maxShakeForJudging = 0.8
    /** 중력 방향이 이보다 크게 바뀌면 폰을 돌린 것(열차 가속으로는 최대 약 9°). */
    var reorientDegrees = 20.0
    var pushSmoothingSeconds = 1.0
    var gravitySeconds = 5.0
    /** 감속을 출발과 반대 방향으로 볼 기준(방향 코사인). */
    var oppositeCosine = -0.3
    var warmupSeconds = 3.0
    /**
     * 폰이 이보다 빨리 돌면 사람이 들거나 내려놓는 중(rad/s, 약 14°/s). 열차가 곡선에서 폰을 돌리는 건 0.1 아래.
     * 손을 뗀 뒤 지금 자세로 중력을 다시 잡는다: 20°보다 작게 기울어도 5°면 0.85 m/s²라 가속으로 착각했다(실기기).
     */
    var handlingRotation = 0.25
    /** 열차 가속·감속은 길어야 20~30초. 같은 힘이 이보다 오래 이어지면 가속이 아니라 기울어진 것(천천히 기울인 경우). */
    var maxPushSeconds = 40.0
    /** 자이로가 이보다 느리게 돈다고 하면 무시한다(rad/s, 약 1.1°/s). 가만히 있어도 나오는 센서 오차가 쌓이면 기울기가 틀어진다. */
    var gyroDeadband = 0.02
}

/** 가속도 센서 값 하나(중력 포함, m/s²). */
struct AccelSample {
    var at: Date
    var x: Double
    var y: Double
    var z: Double
    /** 자이로(rad/s, 폰 기준 x·y·z축 회전). 기울기를 따라가고, 사람이 폰을 만지는지 가린다. */
    var gyro = Vec.zero
    var rotation: Double { gyro.length }
}

/**
 * 가속도에서 열차의 "출발"과 "도착"만 사건으로 뽑는다(Android MotionDetector를 그대로 옮김).
 * - 멈춰 있다가 몇 초 이어지는 꾸준한 밀림 → 출발(밀림이 시작된 시각)
 * - 달리다가 출발과 반대 방향의 꾸준한 밀림(감속)이 끝남 → 도착(감속이 끝난 시각)
 * 걷기·폰 만지기처럼 크게 흔들리는 동안과, 폰을 돌린 직후는 판단하지 않는다.
 */
final class MotionDetector {
    private let rules: MotionRules

    private var gravity: Vec?
    private var push = Vec.zero
    private var shake = 0.0
    private var last: Date?
    private var judgeFrom: Date?

    private var moving = false
    private var departureDirection: Vec?
    /** 폰을 들거나 내려놓는 중이었다. 끝나면 그때 자세를 새 기준으로 잡는다. */
    private var handling = false

    private var burstStart: Date?
    private var burstLastStrong: Date?
    private var burstSum = Vec.zero
    private var burstConfirmed = false

    init(rules: MotionRules = MotionRules()) {
        self.rules = rules
    }

    func accept(_ sample: AccelSample) -> Motion? {
        let raw = Vec(x: sample.x, y: sample.y, z: sample.z)
        let prev = last
        last = sample.at
        guard var g = gravity, let prev else {
            reset(raw, at: sample.at)
            return nil
        }
        let dt = sample.at.timeIntervalSince(prev)
        if dt <= 0 { return nil }
        // 폰이 돈 만큼 중력 방향도 돌려 맞춘다(자이로). 빠르든 느리든 기울기를 "미는 힘"으로 착각하지 않게.
        // 열차 가속은 폰을 돌리지 않으니 자이로가 거의 0이고, 그대로 밀림으로 남는다.
        if sample.gyro.length > rules.gyroDeadband { g = g - sample.gyro.cross(g) * dt }
        gravity = g
        if raw.angleDegrees(g) > rules.reorientDegrees {
            reset(raw, at: sample.at)
            return nil
        }

        let linear = raw - g
        push = blend(push, linear, dt, rules.pushSmoothingSeconds)
        shake = blend(shake, (linear - push).length, dt, rules.pushSmoothingSeconds)
        // 꾸준한 밀림이 없을 때만 중력을 따라간다(열차 가속이 중력에 섞이지 않게)
        if push.length < rules.pushEndThreshold { gravity = blend(g, raw, dt, rules.gravitySeconds) }

        if sample.rotation > rules.handlingRotation || shake > rules.maxShakeForJudging {
            handling = true
            endBurst()
            return nil
        }
        if handling {
            handling = false
            reset(raw, at: sample.at)
            return nil
        }
        if let start = burstStart, sample.at.timeIntervalSince(start) > rules.maxPushSeconds {
            // 가속이 아니라 기울어진 채 그대로였다. 이 밀림으로 낸 "출발"도 틀렸으니 멈춘 것으로 되돌린다
            if burstConfirmed { moving = false }
            reset(raw, at: sample.at)
            return nil
        }
        if let judgeFrom, sample.at < judgeFrom { endBurst(); return nil }
        return track(sample.at, dt)
    }

    private func track(_ at: Date, _ dt: Double) -> Motion? {
        let strength = push.length
        guard let start = burstStart else {
            if strength >= rules.pushThreshold {
                burstStart = at
                burstLastStrong = at
                burstSum = push * dt
                burstConfirmed = false
            }
            return nil
        }
        if strength < rules.pushThreshold {
            let ended = burstConfirmed && moving && isOpposite(burstSum)
            let endedAt = burstLastStrong ?? at
            endBurst()
            if ended {
                moving = false
                return Motion(kind: .stopped, at: endedAt)
            }
            return nil
        }
        burstLastStrong = at
        burstSum = burstSum + push * dt
        if !burstConfirmed && at.timeIntervalSince(start) >= rules.minPushSeconds {
            burstConfirmed = true
            if !moving {
                moving = true
                departureDirection = burstSum
                return Motion(kind: .moving, at: start)
            }
        }
        return nil
    }

    private func isOpposite(_ direction: Vec) -> Bool {
        guard let d = departureDirection else { return false }
        return direction.cosine(d) <= rules.oppositeCosine
    }

    private func reset(_ raw: Vec, at: Date) {
        gravity = raw
        push = .zero
        shake = 0
        judgeFrom = at.addingTimeInterval(rules.warmupSeconds)
        endBurst()
    }

    private func endBurst() {
        burstStart = nil
        burstLastStrong = nil
        burstSum = .zero
        burstConfirmed = false
    }

    /** 지수 평활: 샘플 간격이 들쭉날쭉해도 같은 속도로 따라간다. */
    private func blend(_ old: Vec, _ new: Vec, _ dt: Double, _ tau: Double) -> Vec {
        old + (new - old) * (1 - exp(-dt / tau))
    }

    private func blend(_ old: Double, _ new: Double, _ dt: Double, _ tau: Double) -> Double {
        old + (new - old) * (1 - exp(-dt / tau))
    }
}

struct Vec {
    var x: Double, y: Double, z: Double
    static let zero = Vec(x: 0, y: 0, z: 0)
    static func + (a: Vec, b: Vec) -> Vec { Vec(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z) }
    static func - (a: Vec, b: Vec) -> Vec { Vec(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z) }
    static func * (a: Vec, k: Double) -> Vec { Vec(x: a.x * k, y: a.y * k, z: a.z * k) }
    var length: Double { (x * x + y * y + z * z).squareRoot() }
    func dot(_ o: Vec) -> Double { x * o.x + y * o.y + z * o.z }
    func cross(_ o: Vec) -> Vec { Vec(x: y * o.z - z * o.y, y: z * o.x - x * o.z, z: x * o.y - y * o.x) }
    func cosine(_ o: Vec) -> Double {
        let l = length * o.length
        return l == 0 ? 0 : dot(o) / l
    }
    func angleDegrees(_ o: Vec) -> Double { acos(min(1, max(-1, cosine(o)))) * 180 / .pi }
}
