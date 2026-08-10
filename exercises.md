# Phiếu Phản Ánh — K3 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng placeholder dưới mỗi câu hỏi bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Mạnh Hiệp  Mã học viên: 2A202601319

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Lúc deploy lên Render, tôi set biến `AGENT_API_KEY` trong dashboard. Nếu
> trường này có mặc định `"changeme"`, app vẫn khởi động dù tôi quên set —
> service xanh nhưng thực ra ai biết URL cũng gọi được `/ask` và đốt hết ngân
> sách của tôi; tôi chỉ phát hiện ra khi mở hóa đơn. Vì trường này **không có
> mặc định**, thiếu biến là pydantic ném `ValidationError` → uvicorn báo lỗi
> ngay trong log khởi động và process thoát. Service rớt lúc deploy, tôi thấy
> đỏ ngay trong log mà không cần đợi ai gọi API — chỉ cần set đúng khóa rồi
> redeploy. "Chết sớm" đúng như tên gọi: lỗi cấu hình bị bắt ở lúc khởi động,
> lúc ít người nhìn thấy nhất, thay vì lúc đang phục vụ người dùng thật.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Log thật tôi thu được khi gọi `/ask` 2 lần:
>
> ```text
> {"event": "ask_completed", "level": "info", "timestamp": "2026-08-10T05:50:33.149599+00:00", "user_id": "sv-demo", "tokens_in": 5, "tokens_out": 37, "cost_usd": 2.295e-05}
> {"event": "ask_completed", "level": "info", "timestamp": "2026-08-10T05:50:33.190597+00:00", "user_id": "sv-demo", "tokens_in": 49, "tokens_out": 55, "cost_usd": 4.035e-05}
> ```
>
> Hai việc tôi làm được với log này mà `print("đã trả lời xong")` không làm được:
>
> 1. **Lọc và đếm bằng máy** — jq/Grafana/Datadog đọc một dòng JSON như một
>    object, tôi query được "tổng số request hôm nay", "user nào tốn nhiều
>    nhất" (`select(.user_id == "sv-demo")`). Chuỗi văn bản `"đã trả lời xong"`
>    thì phải grep từng chữ, không thống kê được.
> 2. **Cảnh báo tự động khi chi phí bất thường** — vì có trường `cost_usd`
>    dạng số, tôi đặt ngưỡng "user nào chi > 0.1 USD trong 1 phút thì báo
>    admin" và máy tính được ngay. Muốn làm vậy với log chữ thường phải viết
>    regex bắt số từ một câu, sai một ký tự là hỏng cả pipeline.
>
> Ngoài ra timestamp chuẩn ISO-8601 UTC giúp so khớp log giữa các service
> theo thời gian — `print` thường không kèm thời gian, mà có cũng là giờ máy
> local không thống nhất.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 286 MB |
| Multi-stage | 270 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Số đo thật trên máy tôi: `agent:single` = **286 MB**, `agent:multi` =
> **270 MB** (cả hai nén `docker images` hiển thị ~64–68 MB). Chênh **16 MB**.
>
> Phần chênh lệch chính là các file tạm của quá trình cài đặt: `pip install`
> ngoài các package đã copy sang runtime còn sinh `*.pyc`, cache tải về
> (pip cache), và quan trọng nhất là không dùng `--no-cache-dir` nên pip
> giữ cả bản tải xuống trong layer. Bản 1 stage giữ toàn bộ thứ đó trong
> image; bản multi-stage build dependency trong stage `builder` rồi chỉ
> `COPY --from=builder /install /usr/local` — copy đúng cây thư mục package
> sang stage runtime, mọi file tạm bỏ lại trong `builder` và bị Docker xóa
> khi stage đó không còn được tham chiếu.
>
> 16 MB ở đây không lớn vì requirements của lab chỉ có vài thư viện Python
> thuần. Với project thật (numpy, gcc, CUDA...) chênh lệch thường cả trăm MB
> — và quan trọng hơn kích thước là **thứ bên trong**: bản multi-stage không
> mang theo compiler và toolchain cài package, bề mặt tấn công nhỏ hơn hẳn.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Tôi sửa một dòng trong `app/main.py` rồi build lại, nhìn `docker build`:
>
> ```text
> [builder 4/4] RUN pip install --no-cache-dir --prefix=/install ...  CACHED
> [runtime 5/6] COPY app ./app                                         CACHED
> ```
>
> Toàn bộ các layer phía trước `COPY app ./app` đều **dùng lại từ cache**:
> base image, `COPY requirements.txt`, `RUN pip install`. Chỉ có `COPY app
> ./app` (và các layer sau nó) là **chạy lại**, vì Docker tính cache theo
> checksum nội dung của từng file được copy — main.py đổi → layer `COPY app`
> đổi → các layer sau cũng phải dựng lại.
>
> Điểm mấu chốt của Dockerfile là đặt các bước **thay đổi ít nhất lên
> trước**: `requirements.txt` gần như không bao giờ đổi, còn code thì đổi
> mỗi lần commit. Nếu tôi đặt `COPY . .` lên trước `RUN pip install`, mọi lần
> sửa code đều làm invalidate cả layer `COPY . .`, kéo theo `RUN pip install`
> phải **cài lại toàn bộ thư viện** — mỗi lần build tốn vài phút thay vì vài
> giây, dù chỉ sửa một dấu chấm. Cũng là lý do Dockerfile ghi chú "COPY
> requirements.txt trước, pip install sau và quan trọng là trước khi copy
> source code".

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện nếu container chạy bằng root:
>
> 1. Có một lỗ hổng trong code Python — ví dụ endpoint `/ask` ghép chuỗi
>    không an toàn cho phép chèn lệnh (command injection), hoặc dùng thư
>    viện có CVE bị RCE.
> 2. Kẻ tấn công gửi request khai thác, app chạy code tuỳ ý — và vì process
>    chạy với UID 0, code đó chạy **với quyền root trong container**.
> 3. Root trong container có đủ quyền để làm bước tiếp theo: gắn thêm thiết
>    bị, `nsenter` vào namespace của host, hoặc lợi dụng cấu hình sai của
>    docker daemon (privileged mode, mount thư mục host) để ghi file vào hệ
>    thống của host.
> 4. Chỉ một sai sót cấu hình là "root trong container" thành "root trên máy
>    host" — còn nếu app chạy bằng user thường, lỗ hổng ở bước 2 chỉ cho kẻ
>    tấn công quyền của user đó, không phải root.
>
> Lệnh `USER appuser` trong Dockerfile cắt đứt chuỗi ngay ở bước 2: dù kẻ
> tấn công chạy được code tùy ý, process đó chạy với UID **10001** — không
> phải root — nên các hành động nguy hiểm (mount, ghi file hệ thống) thất
> bại do thiếu quyền. Tôi còn đặt `useradd --uid 10001` chọn UID cố định
> không trùng user nào trên host, để kể cả khi thao tác file dùng chung
> volume thì quyền cũng không vô tình chồng lấn.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> **20 request** — gấp đôi hạn mức.
>
> Với hạn mức 10/phút theo phút đồng hồ, counter reset vào lúc giây 00 của
> mỗi phút. Gọi 2 giây liên tiếp nằm **chênh qua mốc reset** — ví dụ
> `08:59:59.9` và `09:00:00.1`:
>
> - Giây thứ nhất `08:59:59.9`: phút 08:59 chưa reset, trong phút này user
>   đã dùng đủ 10 request (từ 08:59:00) — 10 request đầu nằm trong phút 08:59.
> - Giây thứ hai `09:00:00.1`: phút mới 09:00 đã reset counter về 0, user
>   gửi tiếp **10 request nữa** trong phút 09:00.
>
> Tổng cộng 20 request trong vỏn vẹn 2 giây, tuy 2 request cạnh nhau chỉ cách
> nhau 0,2 giây nhưng "mỗi phút không vượt quá 10" vẫn đúng. Đây là nhược
> điểm cố hữu của fixed window: hai cửa sổ cạnh nhau đều ở mức "đầy" nhưng
> sát vách nhau không có chuyện gì chặn.
>
> Cửa sổ trượt của tôi (Redis Sorted Set, `zremrangebyscore` các entry cũ
> hơn 60 giây trước rồi `zcard` đếm) không có lỗ này: 2 request cách nhau 0,2
> giây luôn nằm **trong cùng một cửa sổ 60 giây trượt**, nên user không thể
> vượt hơn 10 trong bất kỳ khoảng thời gian 60 giây nào.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> Khác nhau ở đơn vị đo. Rate limit đếm **số lượng request** trong một
> khoảng thời gian (10 request/phút/user) — nó không biết mỗi request đắt
> hay rẻ. Cost guard đếm **số tiền đã tiêu** (ngân sách 10 USD/tháng/user) —
> nó không quan tâm request có chậm hay nhiều, chỉ quan tâm tổng chi.
>
> **Rate limit cho qua nhưng cost guard phải chặn:** user gửi 2 request/phút
> (dưới mức 10) nhưng mỗi câu hỏi rất dài — kéo theo cả lịch sử 20 lượt vào
> prompt, `tokens_in` cỡ 50k token mỗi lần → 2 request đốt hết ~0,5 USD.
> Lượt thứ 3 làm tổng tháng vượt 10 USD: rate limit thấy "mới 3 request, ổn"
> nhưng cost guard thấy `spent + ước tính > budget` → chặn 402.
>
> **Cost guard cho qua nhưng rate limit phải chặn:** user mới trong tháng,
> chi tiêu = 0 (còn 10 USD) nhưng viết script loop gửi 100 request/phút. Cost
> guard thấy "chưa tiêu gì, cho qua", còn rate limit đếm được 10 request đầu
> rồi chặn các lần sau bằng 429. Lý do chặn không phải là tốn tiền mà là
> hành vi bất thường — bot spam làm nghẽn server.
>
> Hai lớp bảo vệ cho hai rủi ro khác nhau nên trong `/ask` tôi check **cả
> hai, trước khi gọi LLM** (`limiter.check` rồi `guard.check`) — vì tiền mất
> ở bước gọi LLM, chặn sau bước đó thì vừa mất tiền vừa trả lỗi.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Nếu gộp thành một endpoint vừa là liveness vừa check Redis, chuỗi sự kiện
> với cụm 3 container khi Redis mất kết nối 30 giây:
>
> 1. Redis ngừng trả lời. Load balancer (hoặc orchestrator) gọi endpoint
>    health/liveness đúng chu kỳ (30s).
> 2. Endpoint gộp thử `store.ping()` → Redis không trả lời → trả **503**.
> 3. Orchestrator đọc 503 trên endpoint liveness → kết luận "container chết"
>    → **kill cả 3 container** để thay bằng container mới.
> 4. Container mới khởi động, Redis vẫn chưa quay lại → lại trả 503 → lại
>    bị kill. **Vòng lặp crash-restart** — cả cụm không bao giờ phục vụ.
> 5. 30 giây sau Redis trở lại: mỗi container mới khởi động lại phải trải
>    qua cold start (load code, kết nối Redis), và vì bị restart liên tục
>    trong 30 giây đó, mọi request tới đều rơi vào lúc container đang
>    khởi động → **user thấy 502/503 trong khoảng thời gian dài hơn nhiều so
>    với cú mất kết nối 30 giây ban đầu**.
>
> Đúng cách là tách hai endpoint: `/health` (liveness) **không được phép**
> chạm vào bất kỳ dependency nào — nó chỉ trả lời "process còn sống không",
> nên Redis sập không kéo container đi. Còn `/ready` (readiness) mới check
> Redis; khi Redis chết nó trả 503 để **load balancer rút instance khỏi vòng
> xoay** mà không giết container — Redis quay lại 30 giây sau là instance
> phục vụ tiếp ngay, không mất cold start nào.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Với Redis (stateless): dù `--scale agent=3` và 3 instance ngẫu nhiên xử lý
> các request, `history_length` **vẫn tăng đều** — lượt 1 trả 0, lượt 2 trả
> 2, lượt 3 trả 4... vì mọi instance ghi/đọc cùng một Redis List
> (`history:<user_id>`). Tôi chạy 2 request liên tiếp cùng user cũng thấy
> `history_length` tăng 0 → 2. User không biết request của mình được xử lý
> bởi instance nào — trải nghiệm liền mạch như một agent duy nhất.
>
> Nếu lịch sử nằm trong dict Python trong RAM mỗi process: mỗi instance có
> bản dict riêng, và load balancer phân phối request vòng tròn. Câu hỏi 1
> vào instance A → A nhớ. Câu hỏi 2 có thể vào instance B → B đọc dict của
> mình thấy rỗng → **history_length trả 0** dù đã hỏi 1 câu. Kết quả: con số
> này dao động ngẫu nhiên 0, 2, 0, 2... theo instance nào trúng, agent "mất
> trí nhớ" và trả lời thiếu ngữ cảnh. Tệ hơn, khi deploy bản mới (hoặc
> instance bị restart) là toàn bộ dict biến mất — ngay cả 1 instance cũng mất
> lịch sử. Đó chính là lý do CP4 yêu cầu state sống ngoài process, ở nơi mọi
> instance cùng nhìn thấy.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> Lỗi tôi gặp đầu tiên là với Railway: chạy `railway up` thì bị từ chối
> với thông báo `Your workspace has been restricted. Please attach a payment
> method`. Tôi không thể thêm thẻ vào tài khoản ở thời điểm làm lab, và cứ
> loay hoay thử các lệnh `railway variables` / `railway domain` thì lại tạo
> nhầm domain cho service **redis** thay vì service app — URL trỏ vào Redis
> nên mở lên không ra `/health` gì cả.
>
> Cách tôi tìm ra hướng đi: đọc lại phần deploy của LAB_GUIDE và README thấy
> ghi "Railway **hoặc** Render", nên tôi quyết định **đổi sang Render** thay
> vì mất thêm giờ với một platform đang chặn tài khoản của mình. Tôi tạo
> Blueprint từ file `render.yaml` có sẵn trong repo (Render đọc file này và
> tự tạo cả service `day12-agent` lẫn Redis `day12-redis`, tự nối
> `REDIS_URL` từ service Redis), rồi set biến `AGENT_API_KEY` trong dashboard.
>
> Lỗi thứ hai gặp ngay sau khi deploy lên Render: mở URL thấy `404 Not Found`
> và curl `/health` không trả lời. Tôi xem **log của service trên dashboard**
> thì thấy app chạy được và log ghi `/health 200 OK` — ra là **instance đang
> ngủ** (free tier của Render tự tắt khi không có traffic, lần gọi đầu phải
> chờ cold start ~50 giây). Tôi chờ và gọi lại với timeout dài hơn thì
> `/health` và `/ready` trả 200 bình thường.
>
> Bài học: khi deploy, bước đầu tiên nên đọc log của platform trước khi sửa
> code — log cho biết app chết ở đâu (thiếu env, lỗi import, hay chỉ là
> instance đang ngủ), tránh sửa bậy một thứ không hề hỏng.
