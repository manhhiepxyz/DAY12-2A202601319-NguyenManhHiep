"""CP1 — Structured logging.

`print("user abc hỏi gì đó")` là log cho người đọc. Cloud (Railway, Render,
Cloud Run, Datadog...) đọc log bằng máy: một dòng = một JSON object thì mới
lọc/đếm/cảnh báo được. Đây là khác biệt lớn giữa localhost và production.
"""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone


def utc_now_iso() -> str:
    """CHO SẴN — thời điểm hiện tại theo ISO-8601, múi giờ UTC."""
    return datetime.now(timezone.utc).isoformat()


def log_event(event: str, level: str = "info", **fields) -> str:
    """Ghi một dòng log JSON ra stdout.

    TODO (CP1): tạo dict gồm tối thiểu 3 khóa
        - "event"     : tên sự kiện, lấy từ tham số ``event``
        - "level"     : mức log, VIẾT THƯỜNG (dùng ``level.lower()``)
        - "timestamp" : ``utc_now_iso()``
    rồi gộp thêm mọi cặp key/value trong ``**fields``.

    In chuỗi JSON đó ra stdout **trên một dòng duy nhất**
    (``json.dumps(..., ensure_ascii=False)``, đừng dùng ``indent``) và
    trả về chính chuỗi đó.

    Ví dụ:
        >>> log_event("ask_completed", user_id="sv01", cost_usd=0.0001)
        '{"event": "ask_completed", "level": "info", "timestamp": "...", ...}'
    """
    # Tạo một dict JSON gồm 3 khóa bắt buộc + mọi trường tùy ý trong **fields
    record = {
        "event": event,
        "level": level.lower(),        # level luôn viết thường ("ERROR" → "error")
        "timestamp": utc_now_iso(),    # ISO-8601, múi giờ UTC
        **fields,
    }
    # ensure_ascii=False: giữ tiếng Việt, không thành ạ
    # KHÔNG dùng indent: cloud gom log theo dòng, JSON xuống dòng = log bị vỡ
    line = json.dumps(record, ensure_ascii=False)
    # flush=True: đẩy ngay ra stdout, không nằm trong buffer
    print(line, file=sys.stdout, flush=True)
    return line
