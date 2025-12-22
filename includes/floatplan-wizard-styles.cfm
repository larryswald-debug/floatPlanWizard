<style>
    .wizard-body,
    .wizard-shell {
        background: #f4f6f8;
        min-height: 100vh;
        color: #212529;
    }

    .wizard-shell-embedded {
        min-height: auto;
    }

    .wizard-header {
        background: linear-gradient(135deg, #0d6efd, #0b5ed7);
        color: #fff;
        padding: 1rem;
        box-shadow: 0 2px 8px rgba(0,0,0,0.15);
    }

    .wizard-header .title {
        font-size: 1.35rem;
        margin: 0;
    }

    .wizard-header .wizard-back-link {
        white-space: nowrap;
    }

    .wizard-shell-embedded .wizard-back-link {
        display: none;
    }

    .wizard-container {
        max-width: 820px;
        margin: 1.5rem auto;
        background: #fff;
        border-radius: 16px;
        box-shadow: 0 8px 20px rgba(0,0,0,0.08);
        padding: 1.5rem;
    }

    .wizard-steps .badge {
        font-size: 0.85rem;
        padding: 0.35rem 0.6rem;
        margin-right: 0.35rem;
    }

    .list-group-button {
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    .wizard-nav {
        display: flex;
        justify-content: space-between;
        margin-top: 1.25rem;
    }

    .wizard-alert {
        margin-bottom: 1rem;
    }

    @media (max-width: 768px) {
        .wizard-container {
            margin: 1rem;
            padding: 1rem;
        }
    }
</style>
