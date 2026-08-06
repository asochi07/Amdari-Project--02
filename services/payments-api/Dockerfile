FROM python:3.11

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

EXPOSE 8001

RUN useradd --create-home --uid 10001 appuser && chown -R appuser /app
USER appuser
CMD ["python", "-m", "app.main"]
