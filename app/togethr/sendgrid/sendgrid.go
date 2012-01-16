// Public Domain (-) 2012 The Togethr Authors.
// See the Togethr UNLICENSE file for details.

package sendgrid

import (
	"appengine"
	"http"
	"io/ioutil"
	"togethr/secret"
	"url"
)

type Message struct {
	From     string
	FromAddr string
	To       string
	ToAddr   string
	Subject  string
	Text     string
	HTML     string
}

func Send(ctx appengine.Context, category string, msg *Message) (success bool) {

	p := url.Values{}
	p.Set("api_user", secret.SendgridUser)
	p.Set("api_key", secret.SendgridKey)
	p.Set("x-smtpapi", `{"category": "`+category+`"}`)
	p.Set("fromname", msg.From)
	p.Set("from", msg.FromAddr)
	p.Set("toname", msg.To)
	p.Set("to", msg.ToAddr)
	p.Set("subject", msg.Subject)
	p.Set("text", msg.Text)
	if len(msg.HTML) != 0 {
		p.Set("html", msg.HTML)
	}

	client := &http.Client{}
	resp, err := client.PostForm("https://sendgrid.com/api/mail.send.json", p)

	body, _ := ioutil.ReadAll(resp.Body)
	defer resp.Body.Close()

	if err != nil {
		ctx.Errorf("Sendgrid Error: %v", err)
		return
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		ctx.Errorf("Sendgrid Error Response: %s", body)
		return
	}

	return true

}
