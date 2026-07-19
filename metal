<!DOCTYPE html>
<html lang="th">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>เกมตามล่าหาธาตุโลหะ (AR Chemistry Game)</title>
    
    <!-- นำเข้า MediaPipe -->
    <script src="https://cdn.jsdelivr.net/npm/@mediapipe/camera_utils/camera_utils.js" crossorigin="anonymous"></script>
    <script src="https://cdn.jsdelivr.net/npm/@mediapipe/hands/hands.js" crossorigin="anonymous"></script>
    
    <style>
        body {
            margin: 0;
            overflow: hidden;
            font-family: 'Kanit', sans-serif;
            background-color: #1a1a2e;
            color: white;
            text-align: center;
        }
        #game-container {
            position: relative;
            width: 100vw;
            height: 100vh;
        }
        video {
            display: none; /* ซ่อนวิดีโอต้นฉบับ ใช้ Canvas วาดทับ */
        }
        canvas {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            transform: scaleX(-1); /* สลับซ้ายขวาให้เป็นกระจก */
            z-index: 1;
        }
        /* UI Overlays */
        .ui-layer {
            position: absolute;
            top: 0; left: 0; width: 100%; height: 100%;
            z-index: 10;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            background: rgba(0, 0, 0, 0.7);
        }
        #hud {
            position: absolute;
            top: 20px; width: 100%;
            display: flex;
            justify-content: space-around;
            z-index: 5;
            font-size: 24px;
            font-weight: bold;
            pointer-events: none;
            text-shadow: 2px 2px 4px #000;
        }
        h1 { font-size: 48px; color: #f9ca24; text-shadow: 3px 3px 0 #eb4d4b; margin-bottom: 10px; }
        button {
            padding: 15px 40px;
            font-size: 24px;
            font-weight: bold;
            color: white;
            background: #eb4d4b;
            border: none;
            border-radius: 30px;
            cursor: pointer;
            box-shadow: 0 5px 15px rgba(235, 77, 75, 0.5);
            transition: transform 0.2s;
        }
        button:hover { transform: scale(1.1); }
        .hidden { display: none !important; }
    </style>
</head>
<body>

    <div id="game-container">
        <!-- กล้องและ Canvas -->
        <video id="video" autoplay playsinline></video>
        <canvas id="output_canvas"></canvas>

        <!-- แถบสถานะด้านบน -->
        <div id="hud" class="hidden">
            <div id="scoreDisplay">คะแนน: 0</div>
            <div id="timerDisplay">เวลา: 60</div>
        </div>

        <!-- หน้าจอเริ่มเกม -->
        <div id="startScreen" class="ui-layer">
            <h1>ตามล่าหาธาตุโลหะ</h1>
            <p>ใช้นิ้วชี้ของคุณเจาะดาวที่เป็น "ธาตุโลหะ" เท่านั้น!</p>
            <p>โลหะ +10 | อโลหะ -5</p>
            <button onclick="startGame()">เริ่มเล่นเกม</button>
        </div>

        <!-- หน้าจอสรุปผล -->
        <div id="endScreen" class="ui-layer hidden">
            <h1>หมดเวลา!</h1>
            <h2 id="finalScore">คะแนนรวม: 0</h2>
            <h2 id="medalDisplay">เหรียญรางวัล: </h2>
            <button onclick="location.reload()">เล่นอีกครั้ง</button>
        </div>
    </div>

    <script>
        // ข้อมูลธาตุ
        const metals = ["Li", "Mg", "Ca", "K", "Ra", "Rb", "Ba", "Al", "Na", "Sr", "Cs", "Fr"];
        const nonMetals = ["H", "C", "N", "F", "Cl", "O", "P", "S", "I"];
        
        // ตัวแปรระบบเกม
        let score = 0;
        let timeLeft = 60;
        let isPlaying = false;
        let stars = [];
        let fingerPos = { x: -100, y: -100 };
        let timerInterval;

        const videoElement = document.getElementById('video');
        const canvasElement = document.getElementById('output_canvas');
        const canvasCtx = canvasElement.getContext('2d');

        // ปรับขนาด Canvas
        function resizeCanvas() {
            canvasElement.width = window.innerWidth;
            canvasElement.height = window.innerHeight;
        }
        window.addEventListener('resize', resizeCanvas);
        resizeCanvas();

        // 1. ตั้งค่า MediaPipe Hand Tracking
        const hands = new Hands({locateFile: (file) => {
            return `https://cdn.jsdelivr.net/npm/@mediapipe/hands/${file}`;
        }});
        hands.setOptions({
            maxNumHands: 1,
            modelComplexity: 1,
            minDetectionConfidence: 0.7,
            minTrackingConfidence: 0.7
        });

        hands.onResults((results) => {
            canvasCtx.save();
            canvasCtx.clearRect(0, 0, canvasElement.width, canvasElement.height);
            
            // วาดวิดีโอจากกล้องลง Canvas
            canvasCtx.drawImage(results.image, 0, 0, canvasElement.width, canvasElement.height);

            // ตรวจจับนิ้วชี้ (Landmark 8)
            if (results.multiHandLandmarks && results.multiHandLandmarks.length > 0) {
                const landmarks = results.multiHandLandmarks[0];
                const indexFinger = landmarks[8];
                
                // แปลงพิกัดจาก MediaPipe เป็นพิกัดหน้าจอ
                fingerPos.x = indexFinger.x * canvasElement.width;
                fingerPos.y = indexFinger.y * canvasElement.height;

                // วาดเอฟเฟกต์วงแหวนเรืองแสงที่ปลายนิ้ว
                if (isPlaying) {
                    canvasCtx.beginPath();
                    canvasCtx.arc(fingerPos.x, fingerPos.y, 15, 0, 2 * Math.PI);
                    canvasCtx.fillStyle = "rgba(0, 255, 255, 0.8)";
                    canvasCtx.shadowBlur = 20;
                    canvasCtx.shadowColor = "cyan";
                    canvasCtx.fill();
                    canvasCtx.shadowBlur = 0; // reset
                }
            } else {
                fingerPos = { x: -100, y: -100 };
            }

            // จัดการระบบดาวถ้าเกมเริ่มแล้ว
            if (isPlaying) {
                updateAndDrawStars();
                checkCollisions();
            }

            canvasCtx.restore();
        });

        // เปิดกล้อง
        const camera = new Camera(videoElement, {
            onFrame: async () => {
                await hands.send({image: videoElement});
            },
            width: 1280,
            height: 720
        });
        camera.start();

        // 2. ระบบดาว (Stars)
        function spawnStar() {
            if (!isPlaying) return;
            const isMetal = Math.random() > 0.4; // โอกาสเกิดโลหะ 60%
            const symbolList = isMetal ? metals : nonMetals;
            const symbol = symbolList[Math.floor(Math.random() * symbolList.length)];
            
            stars.push({
                x: Math.random() * (canvasElement.width - 100) + 50,
                y: canvasElement.height + 50,
                radius: 40,
                symbol: symbol,
                isMetal: isMetal,
                speed: Math.random() * 2 + 2, // ความเร็วในการลอยขึ้น
                color: "#f9ca24" // ดาวสีเหลืองสดใส
            });

            setTimeout(spawnStar, 1000 + Math.random() * 1000); // สุ่มเกิดดาวลูกต่อไป
        }

        function updateAndDrawStars() {
            for (let i = stars.length - 1; i >= 0; i--) {
                let star = stars[i];
                star.y -= star.speed; // ลอยขึ้น

                // วาดดาว (รูปวงกลมตัวแทนดาว สำหรับ MVP)
                canvasCtx.beginPath();
                canvasCtx.arc(star.x, star.y, star.radius, 0, 2 * Math.PI);
                canvasCtx.fillStyle = star.color;
                canvasCtx.shadowBlur = 15;
                canvasCtx.shadowColor = "yellow";
                canvasCtx.fill();
                canvasCtx.strokeStyle = "#fff";
                canvasCtx.lineWidth = 3;
                canvasCtx.stroke();
                
                // วาดตัวอักษร
                canvasCtx.shadowBlur = 0;
                canvasCtx.fillStyle = "#000";
                canvasCtx.font = "bold 30px Kanit";
                canvasCtx.textAlign = "center";
                canvasCtx.textBaseline = "middle";
                // กลับด้านข้อความเพื่อไม่ให้กลับซ้ายขวาตามจอ (เนื่องจากเรา scaleX(-1) ไว้)
                canvasCtx.save();
                canvasCtx.translate(star.x, star.y);
                canvasCtx.scale(-1, 1);
                canvasCtx.fillText(star.symbol, 0, 0);
                canvasCtx.restore();

                // ลบดาวที่ลอยหลุดจอ
                if (star.y < -50) stars.splice(i, 1);
            }
        }

        // 3. ระบบชน (Collision) และ คะแนน
        function checkCollisions() {
            for (let i = stars.length - 1; i >= 0; i--) {
                let star = stars[i];
                // คำนวณระยะห่างระหว่างปลายนิ้วกับจุดกึ่งกลางดาว (ทฤษฎีบทพีทาโกรัส)
                let dx = fingerPos.x - star.x;
                let dy = fingerPos.y - star.y;
                let distance = Math.sqrt(dx * dx + dy * dy);

                if (distance < star.radius + 15) { // 15 คือรัศมีปลายนิ้ว
                    if (star.isMetal) {
                        score += 10; // ถูกต้อง
                    } else {
                        score -= 5;  // ผิด
                    }
                    document.getElementById('scoreDisplay').innerText = `คะแนน: ${score}`;
                    stars.splice(i, 1); // ระเบิดดาว (ลบออกจาก Array)
                    // (สามารถเพิ่มเสียง Effect ได้ตรงนี้)
                }
            }
        }

        // 4. ควบคุมเกม (Game Loop)
        function startGame() {
            document.getElementById('startScreen').classList.add('hidden');
            document.getElementById('hud').classList.remove('hidden');
            score = 0;
            timeLeft = 60;
            stars = [];
            isPlaying = true;
            document.getElementById('scoreDisplay').innerText = `คะแนน: ${score}`;
            document.getElementById('timerDisplay').innerText = `เวลา: ${timeLeft}`;

            spawnStar();

            timerInterval = setInterval(() => {
                timeLeft--;
                document.getElementById('timerDisplay').innerText = `เวลา: ${timeLeft}`;
                if (timeLeft <= 0) endGame();
            }, 1000);
        }

        function endGame() {
            isPlaying = false;
            clearInterval(timerInterval);
            document.getElementById('hud').classList.add('hidden');
            document.getElementById('endScreen').classList.remove('hidden');
            document.getElementById('finalScore').innerText = `คะแนนรวม: ${score}`;
            
            let medal = "Bronze 🥉 (พยายามอีกนิด!)";
            if (score >= 150) medal = "Gold 🥇 (เก่งระดับเทพ!)";
            else if (score >= 80) medal = "Silver 🥈 (ยอดเยี่ยม!)";
            
            document.getElementById('medalDisplay').innerText = `เหรียญรางวัล: ${medal}`;
        }
    </script>
</body>
</html>
